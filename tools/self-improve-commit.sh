#!/usr/bin/env bash
#
# self-improve-commit.sh — mechanical guard for agent self-improvement commits.
#
# The single-lineage SELF_IMPROVE checkpoint (agents/build.md) lets the build
# agent apply a grounded, append-only, evidence-backed lesson to an allow-listed
# guidance file in-session. Those self-applies MUST go through this helper (not
# raw `git commit`): it enforces the four non-LLM guards and lands the change as
# its OWN commit carrying a "Self-Improve:" trailer (the audit trail), separate
# from any commits the task's main work made.
#
# Guards (all mechanical; on any failure the edit is left unstaged/uncommitted
# and the helper exits non-zero with the reason):
#   1. Evidence check  — the `path:line` citations in --evidence must exist now.
#   2. Path allow-list  — the target must be allow-listed and off the deny-list
#      (ported verbatim from the retired mcp_server fast-path at
#      modules/home/goals/mcp_server.py:813-848 in git history).
#   3. Append-only diff shape — the staged diff for the target is pure insertion.
#   4. Rate cap — per-session / per-day caps read from
#      ~/.config/opencode/self-improve.json (written by the opencode module from
#      my.programs.opencode.selfImprove.maxCommitsPerSession/maxCommitsPerDay);
#      null / missing / unset = uncapped.
#
# Usage (run from the repo root):
#   tools/self-improve-commit.sh --file <repo-path> \
#     --commit-trailer "Self-Improve: <short-id>" \
#     --evidence "<path>:<line> ..." [-m "message"] [--session-id <id>]
#
# The working edit must already be made in --file; this helper stages only that
# path, validates it, and commits only it (path-limited commit, so it never
# sweeps unrelated staged files).

set -euo pipefail

# ── Config (Decision-2 allow-list / Decision-3 deny-list ported verbatim) ──
SELF_IMPROVE_JSON="${SELF_IMPROVE_JSON:-$HOME/.config/opencode/self-improve.json}"

# Allow-list (Decision 2): prose guidance exactly.
ALLOW_GLOBS=(
  'GOTCHAS.md'
  'EFFICIENCY-PROPOSALS.md'
  'modules/home/opencode/skills/*.md'
  'modules/home/opencode/commands/*.md'
)
# Module AGENT.md RUN LOG sections (any depth, but not under a hard-denied dir).
AGENT_MD_GLOBS=(
  'modules/*/AGENT.md'
  'modules/*/*/AGENT.md'
  'modules/*/*/*/AGENT.md'
  'configurations/AGENT.md'
  'AGENTS.md'
)
# Hard deny-list (Decision-3 fast-path, ported verbatim).
DENY_DIRS=('modules/nixos/secrets/' 'modules/nixos/proxy/' 'modules/nixos/disko/')
DENY_NET_PREFIX='modules/nixos/network'
DENY_FILES=('modules/home/opencode/config.nix' 'modules/home/opencode/options.nix')

# ── Args ─────────────────────────────────────────────────────────────────────
TARGET=""
TRAILER=""
EVIDENCE=""
MESSAGE="self-improve: apply checkpoint lesson"
SESSION_ID=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --file) TARGET="${2:-}"; shift 2 ;;
    --commit-trailer) TRAILER="${2:-}"; shift 2 ;;
    --evidence) EVIDENCE="${2:-}"; shift 2 ;;
    -m|--message) MESSAGE="${2:-}"; shift 2 ;;
    --session-id) SESSION_ID="${2:-}"; shift 2 ;;
    *) echo "self-improve-commit: unknown arg: $1" >&2; exit 2 ;;
  esac
done

fail() { echo "self-improve-commit: REFUSED: $*" >&2; echo "self-improve-commit: edit left unstaged/uncommitted; nothing committed." >&2; exit 1; }

[[ -n "$TARGET" ]] || fail "--file is required"
[[ -n "$TRAILER" ]] || fail "--commit-trailer (a 'Self-Improve: <id>' string) is required"

# Repo root (run from anywhere under the checkout).
REPO_ROOT="$(git -C "$(dirname "$(realpath "${BASH_SOURCE[0]}")")" rev-parse --show-toplevel)"
cd "$REPO_ROOT"
TARGET_FULL="$REPO_ROOT/$TARGET"
[[ -f "$TARGET_FULL" ]] || [[ -e "$TARGET_FULL" ]] || fail "target does not exist on disk: $TARGET"

is_denied() {
  local p="$1"
  for d in "${DENY_DIRS[@]}"; do [[ "$p" == "$d"* ]] && return 0; done
  [[ "$p" == "$DENY_NET_PREFIX"* ]] && return 0
  for f in "${DENY_FILES[@]}"; do [[ "$p" == "$f" ]] && return 0; done
  return 1
}

in_allowlist() {
  local p="$1"
  local g
  for g in "${ALLOW_GLOBS[@]}"; do
    if [[ "$p" == "$g" ]]; then return 0; fi
  done
  for g in "${AGENT_MD_GLOBS[@]}"; do
    if [[ "$p" == "$g" ]]; then return 0; fi
  done
  return 1
}

# ── Guard 2: path allow-list / deny-list ────────────────────────────────────
is_denied "$TARGET" && fail "target is hard-denied ($TARGET)"
in_allowlist "$TARGET" || fail "target is not on the Decision-2 allow-list ($TARGET)"

# ── Guard 1: evidence file:line exists ──────────────────────────────────────
if [[ -n "$EVIDENCE" ]]; then
  # Each evidence citation is a path optionally followed by :<line>. Verify every
  # cited file exists and, when a line is given, that it is within range.
  while read -r tok; do
    [[ -z "$tok" ]] && continue
    path="${tok%%:*}"; line="${tok#*:}"
    if [[ "$line" == "$tok" ]]; then line=""; fi
    if [[ ! -e "$REPO_ROOT/$path" ]]; then
      fail "evidence cites a file that does not exist: $path"
    fi
    if [[ -n "$line" ]] && [[ "$line" =~ ^[0-9]+$ ]]; then
      total="$(wc -l < "$REPO_ROOT/$path")"
      if (( line < 1 || line > total )); then
        fail "evidence cites line $line outside $path ($total lines)"
      fi
    fi
  done < <(printf '%s\n' "$EVIDENCE" | grep -oE '[A-Za-z0-9_./@-]+\.(nix|json|toml|py|md|sh|sql|ts|js|conf|cfg|css|age)(:[0-9]+)?' || true)
fi

# ── Guard 4: rate cap (read from the nix module config) ────────────────────
if [[ -f "$SELF_IMPROVE_JSON" ]]; then
  max_day="$(sed -n 's/.*"maxCommitsPerDay"[[:space:]]*:[[:space:]]*\([0-9][0-9]*\).*/\1/p' "$SELF_IMPROVE_JSON" | head -1)"
  max_sess="$(sed -n 's/.*"maxCommitsPerSession"[[:space:]]*:[[:space:]]*\([0-9][0-9]*\).*/\1/p' "$SELF_IMPROVE_JSON" | head -1)"
  if [[ -n "$max_day" ]]; then
    today="$(git log --since="$(date +%Y-%m-%d)" --format=%H --grep='Self-Improve:' | wc -l)"
    if (( today >= max_day )); then
      fail "daily self-improve cap reached ($today >= $max_day)"
    fi
  fi
  if [[ -n "$max_sess" ]]; then
    if [[ -z "$SESSION_ID" ]]; then
      fail "--session-id is required because a per-session cap (maxCommitsPerSession) is configured"
    fi
    state="$HOME/.local/share/opencode/self-improve-session.count"
    mkdir -p "$(dirname "$state")"
    [[ -f "$state" ]] || echo "0" > "$state"
    n="$(cat "$state")"
    if (( n >= max_sess )); then
      fail "session self-improve cap reached ($n >= $max_sess)"
    fi
  fi
fi

# ── Stage only the target ───────────────────────────────────────────────────
git add -- "$TARGET"

# ── Guard 3: append-only diff shape (pure insertion, allow-listed file) ────
if grep -qE '^-[^-]' < <(git diff --cached -- "$TARGET"); then
  git reset -q -- "$TARGET"
  fail "diff for $TARGET is not pure insertion (contains deletions)"
fi

# ── Commit ONLY this path (never sweeps other staged files) ────────────────
# Subject carries the Self-Improve: trailer so `git log --grep="Self-Improve:"`
# finds it; body is the message.
# Commit ONLY this path (never sweeps other staged files). Subject is the
# `Self-Improve:` trailer verbatim so `git log --grep="Self-Improve:"` finds it
# as the audit trail; body is the message.
git commit -q -m "$TRAILER" -m "$MESSAGE" -- "$TARGET"

# Bump the per-session counter.
if [[ -n "$SESSION_ID" ]]; then
  state="$HOME/.local/share/opencode/self-improve-session.count"
  mkdir -p "$(dirname "$state")"
  n=0; [[ -f "$state" ]] && n="$(cat "$state")"
  echo "$((n + 1))" > "$state"
fi

echo "self-improve-commit: committed: $TRAILER"
echo "self-improve-commit: commit: $(git rev-parse --short HEAD)"