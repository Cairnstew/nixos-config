#!/usr/bin/env bash
# Toggle the general OpenCode provider credential between two agenix secrets.
#
# Swaps the `opencode` + `opencode-zen` entries in
#   ~/.local/share/opencode/auth.json
# between the decrypted contents of:
#   /run/agenix/opencode-token     (shared with opencode-go)
#   /run/agenix/opencode-token-2   (the standalone Zen token)
#
# Why this exists: `opencode-zen.keyFile` is a single static Nix option, so
# switching tokens meant a full `nixos-rebuild switch` (~minutes). auth.json is
# regenerated at activation but merged (jq `. * {...}`), so writing it by hand
# is safe and takes effect on the next opencode restart.
#
# Usage:
#   opencode-key-toggle            # toggle to the other token
#   opencode-key-toggle --status   # show which token is active, change nothing
#   opencode-key-toggle --json     # waybar module output (never fails, never exits non-zero)
#   opencode-key-toggle --to 1|2   # force token 1 (opencode-token) or 2 (token-2)
set -euo pipefail

AUTH_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/opencode"
AUTH_FILE="$AUTH_DIR/auth.json"

TOKEN_1_FILE="/run/agenix/opencode-token"
TOKEN_2_FILE="/run/agenix/opencode-token-2"

# --json is polled by waybar on an interval; it must never exit non-zero and
# must never print anything but JSON to stdout, or waybar logs a parse error
# every tick. Degrade to an "error" state object instead of dying.
JSON_MODE=0
[ "${1:-}" = "--json" ] && JSON_MODE=1

# Emit a waybar custom-module object and exit 0. $1=text $2=tooltip
waybar_emit() {
  jq -nc --arg text "$1" --arg tooltip "$2" \
    '{text: $text, tooltip: $tooltip, class: "oc-key"}'
}

die() {
  if [ "$JSON_MODE" = 1 ]; then
    waybar_emit " OC" "opencode-key-toggle: $1"
    exit 0
  fi
  printf 'opencode-key-toggle: %s\n' "$1" >&2
  exit 1
}

read_key() { tr -d '\n' < "$1"; }

# Ask Waybar to re-exec its custom modules now instead of waiting for the next
# `interval` tick. One Waybar process serves every output, so a single signal
# updates all of them.
#
# Two traps this avoids (both hit in practice):
#   * `killall` is not installed on this host, so `killall -SIGUSR2 waybar`
#     silently did nothing.
#   * Waybar's process comm is `.waybar-wrapped` (a makeCWrapper artifact), NOT
#     `waybar`, so name-based matching fails anyway — and `pkill -f waybar`
#     matches 9 unrelated processes.
# Asking systemd for the unit's MainPID is authoritative and output-agnostic.
waybar_reload() {
  if ! command -v systemctl >/dev/null 2>&1; then
    printf 'opencode-key-toggle: systemctl not found, skipping waybar repaint\n' >&2
    return 0
  fi
  local pid
  pid="$(systemctl --user show -p MainPID --value waybar.service 2>/dev/null || true)"
  case "$pid" in
    '' | 0 | *[!0-9]*)
      printf 'opencode-key-toggle: waybar.service MainPID unusable (%s), skipping repaint\n' "${pid:-empty}" >&2
      return 0
      ;;
  esac
  if ! kill -USR2 "$pid" 2>/dev/null; then
    printf 'opencode-key-toggle: failed to signal waybar (pid %s)\n' "$pid" >&2
  fi
}

KEY_1=""
KEY_2=""
CURRENT=""

# Load both secrets + the live auth.json key. Tolerates every failure by
# recording an error string and leaving the missing pieces blank.
load_state() {
  local err=""
  [ -f "$AUTH_FILE" ] || err="auth.json not found at $AUTH_FILE"

  if [ -r "$TOKEN_1_FILE" ]; then KEY_1="$(read_key "$TOKEN_1_FILE")"; else err="cannot read $TOKEN_1_FILE (agenix did not decrypt it)"; fi
  if [ -r "$TOKEN_2_FILE" ]; then KEY_2="$(read_key "$TOKEN_2_FILE")"; else err="cannot read $TOKEN_2_FILE (agenix did not decrypt it)"; fi
  [ -n "$KEY_1" ] || err="${err:+$err; }opencode-token is empty"
  [ -n "$KEY_2" ] || err="${err:+$err; }opencode-token-2 is empty"

  if [ -f "$AUTH_FILE" ]; then
    CURRENT="$(jq -r '.opencode.key // empty' "$AUTH_FILE" 2>/dev/null || true)"
  fi

  LOAD_ERROR="$err"
}

# Which token (1/2/unknown) is currently in the `opencode` entry.
current_index() {
  case "$1" in
    "$KEY_1") [ -n "$KEY_1" ] && printf '1' ;;
    "$KEY_2") [ -n "$KEY_2" ] && printf '2' ;;
    *) printf '0' ;;
  esac
}

label() {
  case "$1" in
    1) printf 'opencode-token   (shared with opencode-go)' ;;
    2) printf 'opencode-token-2 (standalone Zen token)' ;;
    *) printf 'neither (key set by /connect or manually)' ;;
  esac
}

status() {
  printf 'auth.json : %s\n' "$AUTH_FILE"
  printf 'active    : %s\n' "$(label "$(current_index "$CURRENT")")"
  printf '  opencode-go    : %s...\n' "$(jq -r '.["opencode-go"].key // "unset"' "$AUTH_FILE" | cut -c1-8)"
  printf '  opencode       : %s...\n' "$(jq -r '.opencode.key // "unset"' "$AUTH_FILE" | cut -c1-8)"
  printf '  opencode-zen   : %s...\n' "$(jq -r '.["opencode-zen"].key // "unset"' "$AUTH_FILE" | cut -c1-8)"
}

# Waybar custom-module JSON: which token is live, plus a click hint.
waybar_status() {
  if [ -n "$LOAD_ERROR" ]; then
    waybar_emit " OC" "$LOAD_ERROR"
    return 0
  fi
  case "$(current_index "$CURRENT")" in
    1)
      waybar_emit \
        " <span color='#89b4fa'>OC1</span>" \
        "OpenCode general provider: token 1 (opencode-token, shared with opencode-go)<br>Click to switch to token 2"
      ;;
    2)
      waybar_emit \
        " <span color='#a6e3a1'>OC2</span>" \
        "OpenCode general provider: token 2 (opencode-token-2)<br>Click to switch to token 1"
      ;;
    *)
      waybar_emit \
        " <span color='#f38ba8'>OC?</span>" \
        "OpenCode general provider: active key matches neither token.<br>Click would need --to 1 or --to 2"
      ;;
  esac
}

load_state

case "${1:-}" in
  --status | -s)
    [ -n "$LOAD_ERROR" ] && die "$LOAD_ERROR"
    status
    exit 0
    ;;
  --json)
    waybar_status
    exit 0
    ;;
  --help | -h)
    cat <<'USAGE'
opencode-key-toggle — switch the general OpenCode provider between two tokens

Usage:
  opencode-key-toggle              toggle to the other token
  opencode-key-toggle --status     show which token is active, change nothing
  opencode-key-toggle --json       waybar module output (never exits non-zero)
  opencode-key-toggle --click      toggle + notify + repaint waybar (its on-click)
  opencode-key-toggle --to 1|2     force token 1 (opencode-token) or 2 (token-2)
  opencode-key-toggle --help

Tokens (agenix secrets, decrypted to /run/agenix at activation):
  1  opencode-token     shared with opencode-go
  2  opencode-token-2   standalone Zen token

Writes the `opencode` and `opencode-zen` entries in
~/.local/share/opencode/auth.json. Restart opencode afterwards to pick it up.
A later `nixos-rebuild switch` resets it to whatever `opencode-zen.keyFile`
points at, since the activation script rewrites those entries.
USAGE
    exit 0
    ;;
  --to)
    target="${2:-}"
    case "$target" in
      1) ;;
      2) ;;
      *) die "--to expects 1 or 2 (got '${target}')" ;;
    esac
    ;;
  "")
    # Toggle: move off whatever is active, landing on the other one.
    case "$(current_index "$CURRENT")" in
      1) target=2 ;;
      2) target=1 ;;
      *) die "current 'opencode' key matches neither token — use --to 1 or --to 2 to pick one" ;;
    esac
    ;;
  --click)
    # Waybar on-click: same toggle, plus a desktop notification and an
    # immediate waybar repaint (SIGUSR2) instead of waiting for the next
    # `interval` tick. Kept here rather than as a shell string in the Nix
    # customModule so it stays unit-testable.
    case "$(current_index "$CURRENT")" in
      1) target=2 ;;
      2) target=1 ;;
      *) CLICK_MODE=2
         target=""
         if command -v notify-send >/dev/null 2>&1; then
           notify-send -u critical -a "opencode-key-toggle" \
             "OpenCode key" "Active key matches neither token — use --to 1 or --to 2"
         fi
         waybar_reload
         exit 1
         ;;
    esac
    CLICK_MODE=1
    ;;
  *)
    die "unknown argument '$1' (try --help)"
    ;;
esac

if [ "$target" = 1 ]; then
  NEW_KEY="$KEY_1"
else
  NEW_KEY="$KEY_2"
fi

[ -n "$LOAD_ERROR" ] && die "$LOAD_ERROR"
[ -n "$NEW_KEY" ] || die "refusing to write an empty key"

# Write both entries atomically: opencode/<model> resolves via auth.json["opencode"]
# while opencode-zen needs its own key, so they must stay in sync.
tmp="$AUTH_FILE.tmp.$$"
jq --arg k "$NEW_KEY" \
  '. * {opencode: {type: "api", key: $k}, "opencode-zen": {type: "api", key: $k}}' \
  "$AUTH_FILE" > "$tmp"
chmod 600 "$tmp"
mv "$tmp" "$AUTH_FILE"

if [ "${CLICK_MODE:-0}" = 1 ]; then
  if command -v notify-send >/dev/null 2>&1; then
    notify-send -a "opencode-key-toggle" "OpenCode key" \
      "General provider now: $(label "$target")\nRestart opencode to apply."
  fi
  waybar_reload
  exit 0
fi

printf 'opencode-key-toggle: switched general provider to %s\n' "$(label "$target")"
printf '  opencode      = %s...\n' "${NEW_KEY:0:8}"
printf '  opencode-zen  = %s...\n' "${NEW_KEY:0:8}"
printf 'Restart opencode to pick it up.\n'
