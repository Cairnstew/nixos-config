{ writeShellApplication, gh, jq, git, nixpkgs-fmt, statix, deadnix, coreutils, ... }:

writeShellApplication {
  name = "ci-resolve";

  meta = {
    description = "Diagnose and resolve CI/CD failures with deterministic fixes";
    longDescription = ''
      CLI tool to inspect PRs, CI runs, and attempt deterministic resolution
      of common failures. Returns structured JSON with actionable results.

      Usage:
        ci-resolve status                           # overview of PRs + CI
        ci-resolve diagnose                         # diagnose current branch
        ci-resolve diagnose --pr 123                # diagnose specific PR
        ci-resolve diagnose --run-id 456            # diagnose specific run
        ci-resolve fix                              # attempt auto-fix on current branch
        ci-resolve fix --pr 123                     # fix PR branch

      Actions:
        status      List open PRs with CI status and merge readiness
        diagnose    Analyze failures and return structured diagnosis
        fix         Attempt deterministic fixes (format, lint) and push

      Options:
        --pr NUM            PR number to diagnose/fix
        --run-id ID         Specific run ID to diagnose
        --branch BRANCH     Branch name (default: current branch)
        --repo OWNER/REPO   GitHub repo (auto-detected from git remote)
        --dry-run           Show what would be fixed without applying
        --help              Show this help
    '';
    homepage = "https://cli.github.com/";
    license = "MIT";
    mainProgram = "ci-resolve";
  };

  runtimeInputs = [ gh jq git nixpkgs-fmt statix deadnix coreutils ];

  text = ''
    set -euo pipefail

    ACTION="status"
    PR_NUM=""
    RUN_ID=""
    BRANCH=""
    REPO=""
    DRY_RUN=false

    usage() {
      cat <<EOF
    Usage: $(basename "$0") [ACTION] [OPTIONS]

    Diagnose and resolve CI/CD failures.

    Actions:
      status        Overview of open PRs with CI status (default)
      diagnose      Analyze failures on current branch or specific PR/run
      fix           Attempt deterministic fixes and push

    Options:
      --pr NUM        PR number to diagnose/fix
      --run-id ID     Specific run ID to diagnose
      --branch NAME   Branch (default: current)
      --repo O/R      GitHub repo (auto-detected)
      --dry-run       Show fixes without applying
      --help          Show this help
    EOF
    }

    while [[ $# -gt 0 ]]; do
      case "$1" in
        status|diagnose|fix) ACTION="$1"; shift ;;
        --pr)       PR_NUM="$2"; shift 2 ;;
        --run-id)   RUN_ID="$2"; shift 2 ;;
        --branch)   BRANCH="$2"; shift 2 ;;
        --repo)     REPO="$2"; shift 2 ;;
        --dry-run)  DRY_RUN=true; shift ;;
        --help)     usage; exit 0 ;;
        *) echo "Unknown option: $1"; usage; exit 1 ;;
      esac
    done

    # ── Detect repo ────────────────────────────────────────────────────────
    if [ -z "$REPO" ]; then
      REMOTE=$(git remote get-url origin 2>/dev/null || echo "")
      REPO=$(echo "$REMOTE" | sed -n 's|.*github.com[:/]\([^/]*\)/\([^.]*\).*|\1/\2|p')
    fi

    if [ -z "$REPO" ]; then
      echo '{"error":"repo_detection_failed","message":"Could not detect repo from git remote."}'
      exit 1
    fi

    # ── Detect branch ──────────────────────────────────────────────────────
    if [ -z "$BRANCH" ]; then
      BRANCH=$(git branch --show-current 2>/dev/null || echo "main")
    fi

    # ── gh helper ──────────────────────────────────────────────────────────
    gh_cmd() {
      gh "$@" 2>&1
    }

    # ── Classify CI failure ────────────────────────────────────────────────
    # Returns a JSON object with: type, file, fixable, fix_command
    classify_failure() {
      local log="$1"

      # Format check failure
      if echo "$log" | grep -qi "format.*check\|nixpkgs-fmt\|formatting issue"; then
        local files
        files=$(echo "$log" | grep -oP '(?<=\./)[^\s]+\.nix' | head -5 | jq -R . | jq -s .)
        echo "{\"type\":\"format\",\"fixable\":true,\"fix_command\":\"nix fmt\",\"files\":$files}"
        return 0
      fi

      # Eval check failure
      if echo "$log" | grep -qi "eval.*check\|error:.*attribute.*missing\|undefined variable"; then
        local file line msg
        file=$(echo "$log" | grep -oP '(?<=error: )[^:]+' | head -1)
        line=$(echo "$log" | grep -oP 'line \K[0-9]+' | head -1)
        msg=$(echo "$log" | grep -A2 "error:" | head -3)
        echo "{\"type\":\"eval\",\"fixable\":false,\"file\":\"$file\",\"line\":\"$line\",\"message\":$(echo "$msg" | jq -Rs .)}"
        return 0
      fi

      # Lint check failure (statix/deadnix)
      if echo "$log" | grep -qi "statix\|deadnix\|lint.*check"; then
        local warnings
        warnings=$(echo "$log" | grep -E "^\[W\]|warning:" | head -10 | jq -R . | jq -s .)
        echo "{\"type\":\"lint\",\"fixable\":true,\"fix_command\":\"statix fix + deadnix -l\",\"warnings\":$warnings}"
        return 0
      fi

      # Merge conflict
      if echo "$log" | grep -qi "merge.*conflict\|conflict.*merge\|CONFLICT"; then
        echo "{\"type\":\"merge_conflict\",\"fixable\":true,\"fix_command\":\"git pull --rebase origin $BRANCH\"}"
        return 0
      fi

      # Timeout
      if echo "$log" | grep -qi "timeout\|timed.out"; then
        echo "{\"type\":\"timeout\",\"fixable\":false,\"message\":\"CI job timed out - may need investigation\"}"
        return 0
      fi

      # Generic failure
      echo "{\"type\":\"unknown\",\"fixable\":false,\"message\":$(echo "$log" | tail -5 | jq -Rs .)}"
      return 0
    }

    # ── Get failed job logs ────────────────────────────────────────────────
    get_failed_logs() {
      local run_id="$1"
      local raw
      raw=$(gh_cmd run view "$run_id" --repo "$REPO" --log-failed) || return 0
      echo "$raw" | tail -100
    }

    # ── status ─────────────────────────────────────────────────────────────
    if [ "$ACTION" = "status" ]; then
      # Get open PRs
      PRS=$(gh_cmd pr list --repo "$REPO" --state open --json number,title,headRefName,statusCheckRollup,mergeable,mergeStateStatus,url --limit 20)

      # Get recent runs on current branch
      RUNS=$(gh_cmd run list --repo "$REPO" --branch "$BRANCH" --limit 5 \
        --json databaseId,status,conclusion,headBranch,headSha,event,name,createdAt)

      # Build summary
      PR_SUMMARY=$(echo "$PRS" | jq '[.[] | {
        number: .number,
        title: .title,
        branch: .headRefName,
        mergeable: .mergeable,
        merge_state: .mergeStateStatus,
        url: .url,
        checks: [.statusCheckRollup[]? | {name: .name, conclusion: .conclusion}]
      }]')

      RUN_SUMMARY=$(echo "$RUNS" | jq '[.[] | {
        id: .databaseId,
        name: .name,
        status: .status,
        conclusion: .conclusion,
        branch: .headBranch,
        sha: .headSha,
        created: .createdAt
      }]')

      # Count issues
      FAILED_PRS=$(echo "$PR_SUMMARY" | jq '[.[] | select(.merge_state != "MERGEABLE")] | length')
      FAILED_RUNS=$(echo "$RUN_SUMMARY" | jq '[.[] | select(.conclusion == "failure")] | length')

      jq -n \
        --argjson prs "$PR_SUMMARY" \
        --argjson runs "$RUN_SUMMARY" \
        --argjson failed_prs "$FAILED_PRS" \
        --argjson failed_runs "$FAILED_RUNS" \
        --arg branch "$BRANCH" \
        --arg repo "$REPO" \
        '{
          repo: $repo,
          branch: $branch,
          summary: {
            open_prs: ($prs | length),
            failed_prs: $failed_prs,
            recent_runs: ($runs | length),
            failed_runs: $failed_runs
          },
          prs: $prs,
          recent_runs: $runs
        }'
      exit 0
    fi

    # ── diagnose ───────────────────────────────────────────────────────────
    if [ "$ACTION" = "diagnose" ]; then
      DIAGNOSES="[]"

      # If PR specified, diagnose that PR
      if [ -n "$PR_NUM" ]; then
        PR_INFO=$(gh_cmd pr view "$PR_NUM" --repo "$REPO" --json number,title,headRefName,statusCheckRollup,url)
        PR_BRANCH=$(echo "$PR_INFO" | jq -r '.headRefName')
        CHECKS=$(echo "$PR_INFO" | jq -c '.statusCheckRollup[]?')

        while IFS= read -r check; do
          [ -z "$check" ] && continue
          CONCLUSION=$(echo "$check" | jq -r '.conclusion')
          NAME=$(echo "$check" | jq -r '.name')

          if [ "$CONCLUSION" != "success" ] && [ "$CONCLUSION" != "neutral" ] && [ "$CONCLUSION" != "skipped" ]; then
            # Find the run ID for this check
            RUN_ID_CHECK=$(gh_cmd run list --repo "$REPO" --branch "$PR_BRANCH" --json databaseId,name --limit 20 | \
              jq -r --arg name "$NAME" '.[] | select(.name == $name) | .databaseId' | head -1)

            if [ -n "$RUN_ID_CHECK" ]; then
              LOG=$(get_failed_logs "$RUN_ID_CHECK")
              CLASSIFICATION=$(classify_failure "$LOG")
              DIAGNOSES=$(echo "$DIAGNOSES" | jq --arg name "$NAME" --arg conclusion "$CONCLUSION" \
                --argjson classification "$CLASSIFICATION" \
                '. + [{check: $name, conclusion: $conclusion, classification: $classification}]')
            fi
          fi
        done <<< "$CHECKS"

        echo "$PR_INFO" | jq --argjson diagnoses "$DIAGNOSES" '{
          pr: {number: .number, title: .title, branch: .headRefName, url: .url},
          diagnoses: $diagnoses,
          fixable: [$diagnoses[] | select(.classification.fixable == true)] | length
        }'
        exit 0
      fi

      # If run ID specified, diagnose that run
      if [ -n "$RUN_ID" ]; then
        RUN_INFO=$(gh_cmd run view "$RUN_ID" --repo "$REPO" --json status,conclusion,headBranch,name,jobs,url)
        LOG=$(get_failed_logs "$RUN_ID")
        CLASSIFICATION=$(classify_failure "$LOG")

        echo "$RUN_INFO" | jq --argjson classification "$CLASSIFICATION" '{
          run: {name: .name, branch: .headBranch, url: .url, conclusion: .conclusion},
          classification: $classification,
          fixable: ($classification.fixable)
        }'
        exit 0
      fi

      # Default: diagnose current branch
      RUNS=$(gh_cmd run list --repo "$REPO" --branch "$BRANCH" --limit 3 --json databaseId,name,conclusion,status)

      while IFS= read -r run; do
        [ -z "$run" ] && continue
        RUN_ID_CUR=$(echo "$run" | jq -r '.databaseId')
        RUN_NAME=$(echo "$run" | jq -r '.name')
        RUN_CONCLUSION=$(echo "$run" | jq -r '.conclusion')

        if [ "$RUN_CONCLUSION" = "failure" ] || [ "$RUN_CONCLUSION" = "cancelled" ]; then
          LOG=$(get_failed_logs "$RUN_ID_CUR")
          CLASSIFICATION=$(classify_failure "$LOG")
          DIAGNOSES=$(echo "$DIAGNOSES" | jq --arg name "$RUN_NAME" --arg conclusion "$RUN_CONCLUSION" \
            --arg run_id "$RUN_ID_CUR" --argjson classification "$CLASSIFICATION" \
            '. + [{run_id: $run_id, name: $name, conclusion: $conclusion, classification: $classification}]')
        fi
      done <<< "$(echo "$RUNS" | jq -c '.[]')"

      echo "$DIAGNOSES" | jq '{
        branch: "'"$BRANCH"'",
        diagnoses: .,
        fixable: [.[] | select(.classification.fixable == true)] | length,
        total_failures: length
      }'
      exit 0
    fi

    # ── fix ────────────────────────────────────────────────────────────────
    if [ "$ACTION" = "fix" ]; then
      FIXES_APPLIED="[]"
      FIXES_FAILED="[]"

      # Step 1: Check if we're in a git repo
      if ! git rev-parse --git-dir > /dev/null 2>&1; then
        echo '{"error":"not_a_git_repo","message":"Must be in a git repository to run fix."}'
        exit 1
      fi

      # Step 2: Check for uncommitted changes
      if ! git diff --quiet 2>/dev/null; then
        echo '{"error":"uncommitted_changes","message":"Commit or stash changes before running fix."}'
        exit 1
      fi

      # Step 3: Run nix fmt
      echo "Running nix fmt..." >&2
      if nix fmt 2>/dev/null; then
        FORMATTED_FILES=$(git diff --name-only)
        if [ -n "$FORMATTED_FILES" ]; then
          FIXES_APPLIED=$(echo "$FIXES_APPLIED" | jq '. + ["format: Applied nix formatting"]')
          if [ "$DRY_RUN" = false ]; then
            # shellcheck disable=SC2086
            git add $FORMATTED_FILES
          fi
        else
          echo "  Already formatted." >&2
        fi
      else
        FIXES_FAILED=$(echo "$FIXES_FAILED" | jq '. + ["format: nix fmt failed"]')
      fi

      # Step 4: Run statix fix
      echo "Running statix fix..." >&2
      statix fix 2>/dev/null || true
      STATIX_FILES=$(git diff --name-only | grep '\.nix$' || true)
      if [ -n "$STATIX_FILES" ]; then
        FIXES_APPLIED=$(echo "$FIXES_APPLIED" | jq '. + ["lint: Applied statix fixes"]')
        if [ "$DRY_RUN" = false ]; then
          # shellcheck disable=SC2086
          git add $STATIX_FILES
        fi
      fi

      # Step 5: Run deadnix
      echo "Running deadnix..." >&2
      deadnix -l 2>/dev/null || true
      DEADNIX_FILES=$(git diff --name-only | grep '\.nix$' || true)
      if [ -n "$DEADNIX_FILES" ]; then
        FIXES_APPLIED=$(echo "$FIXES_APPLIED" | jq '. + ["lint: Applied deadnix fixes"]')
        if [ "$DRY_RUN" = false ]; then
          # shellcheck disable=SC2086
          git add $DEADNIX_FILES
        fi
      fi

      # Step 6: Check if there are changes to commit
      CHANGES_STAGED=$(git diff --cached --name-only | wc -l)

      # Build result
      RESULT=$(jq -n \
        --argjson fixes_applied "$FIXES_APPLIED" \
        --argjson fixes_failed "$FIXES_FAILED" \
        --argjson changes_staged "$CHANGES_STAGED" \
        --arg dry_run "$DRY_RUN" \
        --arg branch "$BRANCH" \
        '{
          branch: $branch,
          dry_run: ($dry_run == "true"),
          fixes_applied: $fixes_applied,
          fixes_failed: $fixes_failed,
          changes_staged: $changes_staged,
          ready_to_push: ($changes_staged > 0)
        }')

      echo "$RESULT"

      # If changes staged and not dry-run, offer to commit and push
      if [ "$CHANGES_STAGED" -gt 0 ] && [ "$DRY_RUN" = false ]; then
        echo "" >&2
        echo "Changes staged. To commit and push:" >&2
        echo "  git commit -m 'fix: apply ci-resolve automated fixes'" >&2
        echo "  git push origin $BRANCH" >&2
      fi

      exit 0
    fi
  '';
}
