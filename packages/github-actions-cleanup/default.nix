{ writeShellApplication, gh, curl, jq, gnugrep, gnused, coreutils, ... }:

writeShellApplication {
  name = "github-actions-cleanup";

  meta = {
    description = "Delete old/failed GitHub Actions workflow runs";
    longDescription = ''
      CLI tool to bulk-delete GitHub Actions workflow runs. Supports filtering
      by status (failed, success, cancelled) and age (older than N days).

      Uses `gh` CLI when available (authenticated), falls back to curl + GH_TOKEN.

      Usage:
        github-actions-cleanup --failed
        github-actions-cleanup --older-than 7
        github-actions-cleanup --failed --older-than 30 --yes
        github-actions-cleanup --owner OWNER --repo REPO --status failure --dry-run

      Options:
        --owner OWNER       GitHub owner (auto-detected from git remote)
        --repo REPO         GitHub repo (auto-detected from git remote)
        --token TOKEN       GitHub token (default: $GH_TOKEN or $GITHUB_TOKEN)
        --status STATUS     Filter by status (failure, success, cancelled, etc.)
        --failed            Shorthand for --status failure
        --older-than DAYS   Delete runs older than N days (default: 30)
        --limit N           Max runs to process (default: 500)
        --dry-run           Show what would be deleted without deleting
        --yes, -y           Skip confirmation prompt
    '';
    homepage = "https://cli.github.com/";
    license = "MIT";
    mainProgram = "github-actions-cleanup";
  };
  runtimeInputs = [ gh curl jq gnugrep gnused coreutils ];
  text = ''
    set -euo pipefail

    OWNER=""
    REPO=""
    TOKEN="''${GH_TOKEN:-''${GITHUB_TOKEN:-}}"
    FILTER_STATUS=""
    OLDER_THAN_DAYS=30
    DRY_RUN=false
    LIMIT=500
    CONFIRM=true

    usage() {
      cat <<EOF
    Usage: $(basename "$0") [OPTIONS]

    Delete old/failed GitHub Actions workflow runs.

    Options:
      --owner OWNER       GitHub owner (auto-detected from git remote)
      --repo REPO         GitHub repo (auto-detected from git remote)
      --token TOKEN       GitHub token (default: \$GH_TOKEN)
      --status STATUS     Filter by status (failure, success, cancelled, ...)
      --failed            Shorthand for --status failure
      --older-than DAYS   Delete runs older than N days (default: 30)
      --limit N           Max runs to process (default: 500)
      --dry-run           Show what would be deleted without deleting
      --yes, -y           Skip confirmation prompt
      --help              Show this help
    EOF
    }

    while [[ $# -gt 0 ]]; do
      case "$1" in
        --owner)       OWNER="$2";  shift 2 ;;
        --repo)        REPO="$2";   shift 2 ;;
        --token)       TOKEN="$2";  shift 2 ;;
        --status)      FILTER_STATUS="$2"; shift 2 ;;
        --older-than)  OLDER_THAN_DAYS="$2"; shift 2 ;;
        --limit)       LIMIT="$2";  shift 2 ;;
        --dry-run)     DRY_RUN=true; shift ;;
        --yes|-y)      CONFIRM=false; shift ;;
        --failed)      FILTER_STATUS="failure"; shift ;;
        --help)        usage; exit 0 ;;
        *) echo "Unknown option: $1"; usage; exit 1 ;;
      esac
    done

    if [ -z "$OWNER" ] || [ -z "$REPO" ]; then
      REMOTE=$(git remote get-url origin 2>/dev/null || echo "")
      OWNER=$(echo "$REMOTE" | sed -n 's|.*github.com[/:]\([^/]*\)/\([^.]*\).*|\1|p')
      REPO=$(echo "$REMOTE" | sed -n 's|.*github.com[/:]\([^/]*\)/\([^.]*\).*|\2|p')
    fi

    if [ -z "$OWNER" ] || [ -z "$REPO" ]; then
      echo "Error: Could not detect owner/repo. Use --owner and --repo."
      exit 1
    fi

    echo "Target: $OWNER/$REPO"

    USE_CURL=false
    if command -v gh &>/dev/null && gh auth status &>/dev/null 2>&1; then
      USE_CURL=false
    elif [ -n "$TOKEN" ]; then
      USE_CURL=true
    else
      echo "Error: Need either gh (authenticated) or GH_TOKEN/GITHUB_TOKEN env or --token."
      exit 1
    fi

    API="https://api.github.com/repos/$OWNER/$REPO/actions/runs"

    CUTOFF=""
    if [ "$OLDER_THAN_DAYS" -gt 0 ]; then
      CUTOFF=$(date -u -d "-$OLDER_THAN_DAYS days" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null ||
               date -u -v "-$OLDER_THAN_DAYS"d +%Y-%m-%dT%H:%M:%SZ 2>/dev/null)
    fi

    echo "Filter: status=''${FILTER_STATUS:-any} older-than=$OLDER_THAN_DAYS days''${CUTOFF:+ (before $CUTOFF)}"
    echo "Limit:  $LIMIT"
    echo ""

    CANDIDATE_FILE=$(mktemp)
    trap 'rm -f "$CANDIDATE_FILE"' EXIT

    PAGE=1
    while [ "$(wc -l < "$CANDIDATE_FILE" 2>/dev/null || echo 0)" -lt "$LIMIT" ]; do
      URL="$API?per_page=100&page=$PAGE"

      if $USE_CURL; then
        DATA=$(curl -sL -H "Authorization: Bearer $TOKEN" -H "Accept: application/vnd.github+json" "$URL")
      else
        DATA=$(gh api "$URL" --paginate 2>/dev/null || echo '{"workflow_runs":[]}')
      fi

      RUN_COUNT=$(echo "$DATA" | jq -r '.workflow_runs | length' 2>/dev/null || echo 0)
      [ "$RUN_COUNT" -eq 0 ] && break

      echo "$DATA" | jq -c '.workflow_runs[]' 2>/dev/null | while IFS= read -r run; do
        [ -z "$run" ] && continue
        ID=$(echo "$run" | jq -r '.id // empty')
        CREATED=$(echo "$run" | jq -r '.created_at // ""')
        STATUS=$(echo "$run" | jq -r '.conclusion // .status // "unknown"')
        NAME=$(echo "$run" | jq -r '.name // "unknown"')
        BRANCH=$(echo "$run" | jq -r '.head_branch // "unknown"')
        [ -z "$ID" ] && continue

        [ -n "$FILTER_STATUS" ] && [ "$STATUS" != "$FILTER_STATUS" ] && continue
        [ -n "$CUTOFF" ] && [ "$CREATED" \> "$CUTOFF" ] && continue

        echo "$ID|$STATUS|$NAME|$BRANCH|$CREATED" >> "$CANDIDATE_FILE"

        CURRENT=$(wc -l < "$CANDIDATE_FILE")
        [ "$CURRENT" -ge "$LIMIT" ] && break
      done

      CURRENT=$(wc -l < "$CANDIDATE_FILE")
      [ "$CURRENT" -ge "$LIMIT" ] && break
      PAGE=$((PAGE + 1))
    done

    TOTAL=$(wc -l < "$CANDIDATE_FILE")
    echo ""
    echo "Found $TOTAL candidate runs to delete."

    if [ "$TOTAL" -eq 0 ]; then
      echo "Nothing to do."
      exit 0
    fi

    if $DRY_RUN; then
      echo ""
      echo "Candidate runs:"
      column -t -s '|' "$CANDIDATE_FILE" 2>/dev/null || cat "$CANDIDATE_FILE"
      echo ""
      echo "Dry-run mode. Remove --dry-run to delete."
      exit 0
    fi

    if $CONFIRM; then
      echo ""
      column -t -s '|' "$CANDIDATE_FILE" 2>/dev/null || cat "$CANDIDATE_FILE"
      echo ""
      read -r -p "Delete $TOTAL runs? [y/N] " CONFIRMED
      if [ "$CONFIRMED" != "y" ] && [ "$CONFIRMED" != "Y" ]; then
        echo "Aborted."
        exit 1
      fi
    fi

    echo ""
    DELETED=0
    while IFS='|' read -r id rest; do
      DELETED=$((DELETED + 1))
      echo -n "  [$DELETED/$TOTAL] Deleting #$id ... "
      if $USE_CURL; then
        HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE \
          -H "Authorization: Bearer $TOKEN" \
          -H "Accept: application/vnd.github+json" \
          "$API/$id")
        if [ "$HTTP_STATUS" = "204" ]; then
          echo "deleted"
        else
          echo "FAILED (HTTP $HTTP_STATUS)"
        fi
      else
        if gh api -X DELETE "$API/$id" &>/dev/null; then
          echo "deleted"
        else
          echo "FAILED"
        fi
      fi
    done < "$CANDIDATE_FILE"

    echo ""
    echo "Done. Deleted $DELETED of $TOTAL candidate runs."
  '';
}
