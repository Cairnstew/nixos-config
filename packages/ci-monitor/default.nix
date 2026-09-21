{ writeShellApplication, gh, jq, git, coreutils, ... }:

writeShellApplication {
  name = "ci-monitor";

  meta = {
    description = "Monitor GitHub Actions CI runs with structured JSON output";
    longDescription = ''
      CLI tool to monitor GitHub Actions CI runs. Supports blocking watch
      (waits for run to complete), listing recent runs, and viewing a
      specific run with failure logs. Returns structured JSON.

      Usage:
        ci-monitor                    # watch latest run on current branch
        ci-monitor list               # list 10 most recent runs
        ci-monitor watch              # block until run completes
        ci-monitor view --run-id 123  # view specific run details

      Options:
        --action ACTION    watch (default), list, or view
        --run-id ID        Run ID for watch/view (auto-detected if omitted)
        --branch BRANCH    Branch name (default: current branch)
        --repo OWNER/REPO   GitHub repo (auto-detected from git remote)
        --help             Show this help
    '';
    homepage = "https://cli.github.com/";
    license = "MIT";
    mainProgram = "ci-monitor";
  };

  runtimeInputs = [ gh jq git coreutils ];

  text = ''
    set -euo pipefail

    ACTION="watch"
    RUN_ID=""
    BRANCH=""
    REPO=""

    usage() {
      cat <<EOF
    Usage: $(basename "$0") [OPTIONS]

    Monitor GitHub Actions CI runs.

    Actions:
      (no action)         Watch latest run on current branch (default)
      list                List 10 most recent runs
      watch               Block until run completes
      view                View specific run details

    Options:
      --action ACTION     watch, list, or view
      --run-id ID         Run ID for watch/view (auto-detected if omitted)
      --branch BRANCH     Branch name (default: current branch)
      --repo OWNER/REPO   GitHub repo (auto-detected from git remote)
      --help              Show this help
    EOF
    }

    while [[ $# -gt 0 ]]; do
      case "$1" in
        --action)    ACTION="$2"; shift 2 ;;
        --run-id)    RUN_ID="$2"; shift 2 ;;
        --branch)    BRANCH="$2"; shift 2 ;;
        --repo)      REPO="$2"; shift 2 ;;
        --help)      usage; exit 0 ;;
        list|watch|view) ACTION="$1"; shift ;;
        *) echo "Unknown option: $1"; usage; exit 1 ;;
      esac
    done

    # ── Detect repo ────────────────────────────────────────────────────────
    if [ -z "$REPO" ]; then
      REMOTE=$(git remote get-url origin 2>/dev/null || echo "")
      # SSH: git@github.com:owner/repo.git
      REPO=$(echo "$REMOTE" | sed -n 's|.*github.com[:/]\([^/]*\)/\([^.]*\).*|\1/\2|p')
    fi

    if [ -z "$REPO" ]; then
      echo '{"error":"repo_detection_failed","message":"Could not detect repo from git remote. Pass --repo explicitly (e.g. Cairnstew/nixos-config)."}'
      exit 1
    fi

    # ── Detect branch ──────────────────────────────────────────────────────
    if [ -z "$BRANCH" ]; then
      BRANCH=$(git branch --show-current 2>/dev/null || echo "main")
    fi

    # ── Detect HEAD SHA ────────────────────────────────────────────────────
    HEAD_SHA=$(git rev-parse HEAD 2>/dev/null || echo "")

    # ── gh helper ──────────────────────────────────────────────────────────
    gh_cmd() {
      gh "$@" 2>&1
    }

    # ── list ───────────────────────────────────────────────────────────────
    if [ "$ACTION" = "list" ]; then
      gh_cmd run list --repo "$REPO" --branch "$BRANCH" \
        --limit 10 --json databaseId,status,conclusion,headBranch,headSha,event,createdAt,updatedAt
      exit 0
    fi

    # ── find run by SHA ────────────────────────────────────────────────────
    find_run_by_sha() {
      local sha="$1"
      for attempt in $(seq 1 8); do
        local raw
        raw=$(gh_cmd run list --repo "$REPO" --branch "$BRANCH" \
          --json databaseId,headSha --limit 10) || true

        local match
        match=$(echo "$raw" | jq -r --arg sha "$sha" \
          '.[] | select(.headSha == $sha) | .databaseId' 2>/dev/null | head -1)

        if [ -n "$match" ] && [ "$match" != "null" ]; then
          echo "$match"
          return 0
        fi

        if [ "$attempt" -lt 8 ]; then
          sleep 10
        fi
      done
      return 1
    }

    # ── fetch run details ──────────────────────────────────────────────────
    fetch_run_details() {
      local run_id="$1"
      gh_cmd run view "$run_id" --repo "$REPO" \
        --json status,conclusion,headBranch,headSha,event,url,createdAt,updatedAt,jobs
    }

    # ── fetch log excerpt ──────────────────────────────────────────────────
    fetch_log_excerpt() {
      local run_id="$1"
      local raw
      raw=$(gh_cmd run view "$run_id" --repo "$REPO" --log-failed) || return 0
      local last100
      last100=$(echo "$raw" | tail -100)
      if [ "''${#last100}" -gt 2000 ]; then
        echo "$last100" | tail -c 2000
      else
        echo "$last100"
      fi
    }

    # ── build result ───────────────────────────────────────────────────────
    build_result() {
      local details="$1"
      local log_excerpt="$2"

      local created updated duration
      created=$(echo "$details" | jq -r '.createdAt // empty')
      updated=$(echo "$details" | jq -r '.updatedAt // empty')

      if [ -n "$created" ] && [ -n "$updated" ]; then
        local created_ts updated_ts
        created_ts=$(date -d "$created" +%s 2>/dev/null || date -jf "%Y-%m-%dT%H:%M:%SZ" "$created" +%s 2>/dev/null || echo 0)
        updated_ts=$(date -d "$updated" +%s 2>/dev/null || date -jf "%Y-%m-%dT%H:%M:%SZ" "$updated" +%s 2>/dev/null || echo 0)
        duration=$(( updated_ts - created_ts ))
      else
        duration="null"
      fi

      local conclusion
      conclusion=$(echo "$details" | jq -r '.conclusion // "null"')

      # Build failed_jobs array
      local failed_jobs
      failed_jobs=$(echo "$details" | jq -c '[.jobs[]? | select(.conclusion != "success") | .name]')

      # Build jobs array
      local jobs
      jobs=$(echo "$details" | jq -c '[.jobs[]? | {name, conclusion}]')

      # Log excerpt only for failures
      local log_json="null"
      if [ "$conclusion" != "success" ] && [ -n "$log_excerpt" ]; then
        log_json=$(echo "$log_excerpt" | jq -Rs .)
      fi

      jq -n \
        --arg status "$(echo "$details" | jq -r '.status')" \
        --arg conclusion "$conclusion" \
        --arg run_id "$(echo "$details" | jq -r '.databaseId // .id')" \
        --arg branch "$(echo "$details" | jq -r '.headBranch')" \
        --arg repo "$REPO" \
        --arg url "$(echo "$details" | jq -r '.url')" \
        --argjson duration "$duration" \
        --argjson jobs "$jobs" \
        --argjson failed_jobs "$failed_jobs" \
        --argjson log_excerpt "$log_json" \
        '{
          status: $status,
          conclusion: $conclusion,
          run_id: $run_id,
          branch: $branch,
          repo: $repo,
          url: $url,
          duration_seconds: $duration,
          jobs: $jobs,
          failed_jobs: $failed_jobs,
          log_excerpt: $log_excerpt
        }'
    }

    # ── view ───────────────────────────────────────────────────────────────
    if [ "$ACTION" = "view" ]; then
      if [ -z "$RUN_ID" ]; then
        echo '{"error":"missing_run_id","message":"action=view requires --run-id. Use list to find a run ID, or watch to auto-detect."}'
        exit 1
      fi

      details=$(fetch_run_details "$RUN_ID")
      log_excerpt=""
      conclusion=$(echo "$details" | jq -r '.conclusion // "null"')
      if [ "$conclusion" != "success" ]; then
        log_excerpt=$(fetch_log_excerpt "$RUN_ID")
      fi
      build_result "$details" "$log_excerpt"
      exit 0
    fi

    # ── watch (default) ────────────────────────────────────────────────────

    # Resolve run_id via SHA match if not provided
    if [ -z "$RUN_ID" ]; then
      if [ -z "$HEAD_SHA" ]; then
        echo '{"error":"git_error","message":"Could not determine HEAD SHA."}'
        exit 1
      fi

      RUN_ID=$(find_run_by_sha "$HEAD_SHA") || {
        echo "{\"error\":\"run_not_found\",\"message\":\"No run found for commit $HEAD_SHA on branch $BRANCH after 80s\",\"sha\":\"$HEAD_SHA\",\"branch\":\"$BRANCH\"}"
        exit 1
      }
    fi

    # Block until run completes
    if ! gh_cmd run watch "$RUN_ID" --repo "$REPO" --exit-status --exit-name complete; then
      # run failed/cancelled — that's expected, proceed to fetch details
      :
    fi

    # Fetch full details and build result
    details=$(fetch_run_details "$RUN_ID")
    log_excerpt=""
    conclusion=$(echo "$details" | jq -r '.conclusion // "null"')
    if [ "$conclusion" != "success" ]; then
      log_excerpt=$(fetch_log_excerpt "$RUN_ID")
    fi
    build_result "$details" "$log_excerpt"
  '';
}
