#!/usr/bin/env bash
# =============================================================================
# install.sh — install a built ThunderStore pack into the Steam game directory
# =============================================================================
# Usage: install.sh <manifest.json> [options]
#
#   --target DIR     install into DIR instead of the discovered game directory
#   --steam-root DIR treat DIR as a Steam root (skip library discovery)
#   --appid ID      override the Steam appid used for discovery
#   --dry-run        print every planned write/prune, touch nothing
#   --force          overwrite files we do not own, and prune modified files
#   --prune-only     remove previously-installed files, install nothing
#   --require-exe    fail (instead of warn) when the game's exe is missing
#   --no-state       do not read/write the ownership state file (no pruning)
#   --no-prune       install, but keep files a previous install wrote
#   --state-file F   name of the ownership record (default .thunderstore-state.json)
#   --json           emit the machine-readable result summary on stdout
#
# Discovery order for the game directory:
#   1. --target
#   2. appmanifest_<appid>.acf in every Steam library -> "installdir"  (authoritative)
#   3. <library>/steamapps/common/<steamFolderName>  (also case-insensitively)
#   4. the nested-steamFolderName correction (14 games nest their install dir,
#      e.g. steamFolderName "The Lab/TheLab/win64")
#
# Ownership: every file we write is recorded in <gameDir>/.thunderstore-state.json
# with its sha256. A later install only prunes files that (a) we previously wrote
# and (b) still hash to what we wrote - a file you have since edited is reported,
# never silently deleted, unless --force.
#
# Dependencies: bash, coreutils, jq, sha256sum. Nix wrappers always provide them.
# =============================================================================

set -euo pipefail

MANIFEST="${1:?usage: install.sh <manifest.json> [options]}"
shift || true

TARGET=""
STEAM_ROOT=""
APPID_OVERRIDE=""
DRY_RUN=0
FORCE=0
PRUNE_ONLY=0
REQUIRE_EXE=0
USE_STATE=1
PRUNE=1
EMIT_JSON=0
STATE_FILE_NAME=".thunderstore-state.json"

while [ $# -gt 0 ]; do
  case "$1" in
    --target) TARGET="${2:?--target needs a value}"; shift 2 ;;
    --steam-root) STEAM_ROOT="${2:?--steam-root needs a value}"; shift 2 ;;
    --appid) APPID_OVERRIDE="${2:?--appid needs a value}"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --force) FORCE=1; shift ;;
    --prune-only) PRUNE_ONLY=1; shift ;;
    --require-exe) REQUIRE_EXE=1; shift ;;
    --no-state) USE_STATE=0; shift ;;
    --no-prune) PRUNE=0; shift ;;
    --state-file) STATE_FILE_NAME="${2:?--state-file needs a value}"; shift 2 ;;
    --json) EMIT_JSON=1; shift ;;
    -h|--help) sed -n '2,30p' "$0"; exit 0 ;;
    *) echo "install.sh: unknown option $1" >&2; exit 2 ;;
  esac
done

command -v jq >/dev/null || { echo "install.sh: jq is required" >&2; exit 3; }

MANIFEST_DIR="${MANIFEST%/*}"
PROFILE_DIR="$MANIFEST_DIR/profile"
if [ ! -d "$PROFILE_DIR" ]; then
  MANIFEST_DIR=$(dirname "$MANIFEST")
  PROFILE_DIR="$MANIFEST_DIR/profile"
fi
[ -d "$PROFILE_DIR" ] || { echo "install.sh: no profile dir beside $MANIFEST" >&2; exit 3; }

PACK=$(jq -r '.pack.name // "unknown-pack"' "$MANIFEST")
GAME_LABEL=$(jq -r '.game.label // "unknown-game"' "$MANIFEST")
GAME_NAME=$(jq -r '.game.displayName // .game.label // "unknown-game"' "$MANIFEST")
# The ecosystem's appid is authoritative; --appid exists so a pack can be pointed
# at a different copy of the game (and so it can mirror
# my.programs.steam.games.<name>.appId when that is the number you trust).
APPID=$(jq -r '.game.steamAppId // ""' "$MANIFEST")
[ -n "$APPID_OVERRIDE" ] && APPID="$APPID_OVERRIDE"
STEAM_FOLDER=$(jq -r '.game.steamFolderName // ""' "$MANIFEST")
DATA_FOLDER=$(jq -r '.game.dataFolderName // ""' "$MANIFEST")
LOADER=$(jq -r '.loader // "unknown"' "$MANIFEST")

log() {
  if [ "$EMIT_JSON" -eq 0 ]; then
    printf '%s\n' "$*" >&2
  fi
}

sha256_of() {
  sha256sum "$1" | cut -d' ' -f1
}

# --------------------------------------------------------------------------- #
# Steam library discovery
# --------------------------------------------------------------------------- #

steam_candidates() {
  if [ -n "$STEAM_ROOT" ]; then
    printf '%s\n' "$STEAM_ROOT"
    return
  fi
  printf '%s\n' \
    "${XDG_DATA_HOME:-$HOME/.local/share}/Steam" \
    "$HOME/.steam/steam" \
    "$HOME/.steam/root" \
    "$HOME/.local/share/Steam" \
    "$HOME/Steam" \
    "$HOME/.var/app/com.valvesoftware.Steam/.local/share/Steam"
}

parse_vdf_paths() {
  # libraryfolders.vdf holds "path" "/mnt/games" (indentation varies by version)
  sed -n 's/^[[:space:]]*"path"[[:space:]]*"\(.*\)"[[:space:]]*$/\1/p' "$1"
}

acf_installdir() {
  # appmanifest_<appid>.acf holds the authoritative install dir name.
  sed -n 's/^[[:space:]]*"installdir"[[:space:]]*"\(.*\)"[[:space:]]*$/\1/p' "$1" | head -n1
}

steam_libraries() {
  local root vdf p
  while read -r root; do
    [ -n "$root" ] || continue
    [ -d "$root/steamapps" ] || continue
    printf '%s\n' "$root"
    vdf="$root/steamapps/libraryfolders.vdf"
    if [ -f "$vdf" ]; then
      while read -r p; do
        [ -n "$p" ] || continue
        p=$(printf '%s' "$p" | tr '\\' '/')
        [ -d "$p/steamapps" ] && printf '%s\n' "$p"
      done < <(parse_vdf_paths "$vdf")
    fi
  done < <(steam_candidates) | awk '!seen[$0]++'
}

nested_fixup() {
  # 14 games install into a nested folder: steamFolderName "The Lab/TheLab/win64".
  local found="$1" folder="$2" tail head
  case "$folder" in
    */*) ;;
    *) return 0 ;;
  esac
  tail="${folder##*/}"
  if [ "$(basename "$found")" = "$tail" ]; then
    head="${folder%/*}"
    printf '%s\n' "$(dirname "$found")/$head"
  fi
}

discover_game_dir() {
  local lib acf installdir candidate fixed entry lower want
  want=$(printf '%s' "$STEAM_FOLDER" | tr '[:upper:]' '[:lower:]')

  # 1. appmanifest_<appid>.acf is authoritative
  if [ -n "$APPID" ]; then
    while read -r lib; do
      [ -n "$lib" ] || continue
      acf="$lib/steamapps/appmanifest_$APPID.acf"
      [ -f "$acf" ] || continue
      installdir=$(acf_installdir "$acf")
      [ -n "$installdir" ] || continue
      candidate="$lib/steamapps/common/$installdir"
      fixed=$(nested_fixup "$candidate" "$STEAM_FOLDER")
      if [ -n "$fixed" ] && [ -d "$fixed" ]; then
        printf '%s\n' "$fixed"
        return 0
      fi
      printf '%s\n' "$candidate"
      return 0
    done < <(steam_libraries)
  fi

  # 2. guess by folder name, case-insensitively (Steam lowercases some installs)
  while read -r lib; do
    [ -n "$lib" ] && [ -n "$want" ] || continue
    candidate="$lib/steamapps/common/$STEAM_FOLDER"
    if [ -d "$candidate" ]; then
      printf '%s\n' "$candidate"
      return 0
    fi
    for entry in "$lib/steamapps/common/"*; do
      [ -d "$entry" ] || continue
      lower=$(basename "$entry" | tr '[:upper:]' '[:lower:]')
      if [ "$lower" = "$want" ]; then
        printf '%s\n' "$entry"
        return 0
      fi
    done
  done < <(steam_libraries)
  return 1
}

# --------------------------------------------------------------------------- #
# Destination mapping (names come from lib/loaders.nix)
# --------------------------------------------------------------------------- #

dest_root() {
  case "$1" in
    gameRoot)
      printf '%s\n' "$GAME_DIR"
      ;;
    dataBinaries)
      if [ -z "$DATA_FOLDER" ]; then
        echo "install.sh: destination dataBinaries needs a dataFolderName; this game has none" >&2
        exit 4
      fi
      printf '%s\n' "$GAME_DIR/$DATA_FOLDER/Binaries/Win64"
      ;;
    releaseDir)
      printf '%s\n' "$GAME_DIR/Release"
      ;;
    *)
      echo "install.sh: unknown destination '$1'" >&2
      exit 4
      ;;
  esac
}

# --------------------------------------------------------------------------- #
# Locate the game
# --------------------------------------------------------------------------- #

if [ -n "$TARGET" ]; then
  GAME_DIR="$TARGET"
  DISCOVERY="--target"
else
  GAME_DIR=""
  if GAME_DIR=$(discover_game_dir); then :; else GAME_DIR=""; fi
  DISCOVERY="steam-discovery"
fi

if [ -z "$GAME_DIR" ]; then
  log "thunderstore: $GAME_NAME (appid ${APPID:-?}) is not installed."
  log "  Install it via Steam first, or pass --target <dir>."
  if [ "$EMIT_JSON" -eq 1 ]; then
    jq -n --arg pack "$PACK" --arg game "$GAME_NAME" \
      '{status:"game-not-found", pack:$pack, game:$game, wrote:0, removed:0}'
  fi
  exit 5
fi

# Nested layout: discovery already applied it, --target has not.
if [ -n "$TARGET" ]; then
  fixed=$(nested_fixup "$GAME_DIR" "$STEAM_FOLDER")
  [ -n "$fixed" ] && GAME_DIR="$fixed"
fi

if [ ! -d "$GAME_DIR" ]; then
  log "thunderstore: $GAME_DIR does not exist ($DISCOVERY)"
  exit 5
fi

log "thunderstore: pack '$PACK' -> $GAME_NAME"
log "  loader:      $LOADER"
log "  appid:       ${APPID:-n/a}"
log "  game dir:    $GAME_DIR  ($DISCOVERY)"

# Mods load through the game's binary, so a wrong directory is the classic
# failure. Warn loudly; --require-exe makes it fatal.
# Exe names contain spaces ("Lethal Company.exe"), so read them line by line
# instead of word-splitting.
EXE_NAMES=$(jq -r '(.game.exeNames // []) | join("\n")' "$MANIFEST")
if [ -n "$EXE_NAMES" ]; then
  found_exe=""
  while read -r exe; do
    [ -n "$exe" ] || continue
    if [ -f "$GAME_DIR/$exe" ]; then
      found_exe="$exe"
      break
    fi
  done <<EOF
$EXE_NAMES
EOF
  if [ -z "$found_exe" ]; then
    if [ "$REQUIRE_EXE" -eq 1 ]; then
      log "thunderstore: none of the game's executables are in $GAME_DIR (want: $(printf '%s' "$EXE_NAMES" | tr '\n' ' '))"
      log "  The install directory is probably wrong - refusing to continue."
      exit 6
    fi
    log "  warning:     no game executable in $GAME_DIR (want: $(printf '%s' "$EXE_NAMES" | tr '\n' ' '))"
    log "               mods were still installed; check the path if the game misbehaves"
  else
    log "  exe:         $found_exe"
  fi
fi

STATE_FILE="$GAME_DIR/$STATE_FILE_NAME"
if [ "$USE_STATE" -eq 1 ] && [ -f "$STATE_FILE" ]; then
  OLD_FILES=$(jq -r '.files[]? | [.dest, .path, .sha256Hex] | @tsv' "$STATE_FILE")
else
  OLD_FILES=""
fi

# --------------------------------------------------------------------------- #
# Plan: writes and prunes
# --------------------------------------------------------------------------- #

PLAN_WRITE=""
PLAN_PRUNE=""
NOTES=""
WROTE=0
REMOVED=0
SKIPPED=0

add_note() {
  if [ -z "$NOTES" ]; then
    NOTES="$1"
  else
    NOTES="$NOTES
$1"
  fi
}

contains_line() {
  # contains_line <needle> <haystack>: exact-line membership test
  printf '%s\n' "$2" | grep -qFx -- "$1"
}

if [ "$USE_STATE" -eq 1 ] && [ "$PRUNE" -eq 1 ] && [ -n "$OLD_FILES" ]; then
  DESIRED=$(jq -r '.files[]? | [.dest, .path] | @tsv' "$MANIFEST")
  while IFS="$(printf '\t')" read -r old_dest old_path old_hex; do
    [ -n "$old_path" ] || continue
    if contains_line "$old_dest$(printf '\t')$old_path" "$DESIRED"; then
      continue
    fi
    root=$(dest_root "$old_dest")
    target="$root/$old_path"
    if [ ! -e "$target" ]; then
      continue
    fi
    current=$(sha256_of "$target")
    if [ "$current" != "$old_hex" ] && [ "$FORCE" -eq 0 ]; then
      add_note "kept modified $old_dest/$old_path (pass --force to remove)"
      continue
    fi
    PLAN_PRUNE="$PLAN_PRUNE$old_dest$(printf '\t')$old_path
"
  done <<EOF
$OLD_FILES
EOF
fi

if [ "$PRUNE_ONLY" -eq 0 ]; then
  TAB=$(printf '\t')
  while IFS="$TAB" read -r dest rel source sha sha_hex mode; do
    [ -n "$rel" ] || continue
    root=$(dest_root "$dest")
    src_path="$PROFILE_DIR/$dest/$rel"
    target="$root/$rel"

    if [ ! -f "$src_path" ]; then
      echo "install.sh: built profile is missing $dest/$rel" >&2
      exit 7
    fi

    if [ -e "$target" ]; then
      current=$(sha256_of "$target")
      if [ "$current" = "$sha_hex" ]; then
        SKIPPED=$((SKIPPED + 1))
        continue
      fi
      if ! contains_line "$dest$TAB$rel" "$OLD_FILES"; then
        if [ "$FORCE" -eq 0 ]; then
          add_note "skipped untracked $dest/$rel (pass --force to overwrite)"
          SKIPPED=$((SKIPPED + 1))
          continue
        fi
        add_note "overwrote untracked $dest/$rel (--force)"
      fi
    fi

    PLAN_WRITE="$PLAN_WRITE$dest$TAB$rel$TAB$src_path$TAB$target$TAB$sha_hex$TAB$mode
"
  done <<EOF
$(jq -r '.files[] | [.dest, .path, .source, .sha256, .sha256Hex, .mode] | @tsv' "$MANIFEST")
EOF
fi

# --------------------------------------------------------------------------- #
# Report / apply
# --------------------------------------------------------------------------- #

TAB=$(printf '\t')
FILE_COUNT=$(jq -r '.files | length' "$MANIFEST")
WRITE_COUNT=$(printf '%s' "$PLAN_WRITE" | grep -c '' || true)
PRUNE_COUNT=$(printf '%s' "$PLAN_PRUNE" | grep -c '' || true)

log "  files:       $FILE_COUNT in profile, $WRITE_COUNT to write, $PRUNE_COUNT to prune, $SKIPPED unchanged"
if [ -n "$NOTES" ]; then
  while read -r note; do
    [ -n "$note" ] && log "  note:        $note"
  done <<EOF
$NOTES
EOF
fi

if [ "$DRY_RUN" -eq 1 ]; then
  log "  dry run:     no changes made"
  while IFS="$TAB" read -r dest rel src target hex mode; do
    [ -n "$rel" ] || continue
    root=$(dest_root "$dest")
    log "    write $root/$rel"
  done <<EOF
$PLAN_WRITE
EOF
  while IFS="$TAB" read -r dest rel; do
    [ -n "$rel" ] || continue
    root=$(dest_root "$dest")
    log "    prune $root/$rel"
  done <<EOF
$PLAN_PRUNE
EOF
fi

if [ "$DRY_RUN" -eq 0 ]; then
  while IFS="$TAB" read -r dest rel src target hex mode; do
    [ -n "$rel" ] || continue
    mkdir -p "$(dirname "$target")"
    cp -f -- "$src" "$target"
    chmod "$mode" "$target" 2>/dev/null || true
    WROTE=$((WROTE + 1))
  done <<EOF
$PLAN_WRITE
EOF

  while IFS="$TAB" read -r dest rel; do
    [ -n "$rel" ] || continue
    root=$(dest_root "$dest")
    target="$root/$rel"
    if [ -e "$target" ]; then
      rm -f "$target"
      REMOVED=$((REMOVED + 1))
    fi
  done <<EOF
$PLAN_PRUNE
EOF

  # Drop directories that pruning emptied (deepest first, never non-empty).
  while IFS="$TAB" read -r dest rel; do
    [ -n "$rel" ] || continue
    root=$(dest_root "$dest")
    dir=$(dirname "$root/$rel")
    while [ "$dir" != "$GAME_DIR" ] && [ "${dir#"$GAME_DIR"/}" != "$dir" ]; do
      rmdir "$dir" 2>/dev/null || break
      dir=$(dirname "$dir")
    done
  done <<EOF
$PLAN_PRUNE
EOF

  if [ "$USE_STATE" -eq 1 ]; then
    TMP_STATE=$(mktemp)
    jq -n \
      --arg pack "$PACK" \
      --arg game "$GAME_NAME" \
      --arg gameDir "$GAME_DIR" \
      --arg loader "$LOADER" \
      --arg installedAt "$(date -Is 2>/dev/null || echo unknown)" \
      --slurpfile plan "$MANIFEST" \
      '{pack: $pack, game: $game, gameDir: $gameDir, loader: $loader,
        installedAt: $installedAt,
        note: "managed by my.programs.thunderstore - delete this file to stop pruning",
        files: $plan[0].files, dirs: $plan[0].dirs}' >"$TMP_STATE"
    mv "$TMP_STATE" "$STATE_FILE"
  fi

  log "thunderstore: wrote $WROTE file(s), removed $REMOVED, $SKIPPED unchanged"
fi

if [ "$EMIT_JSON" -eq 1 ]; then
  if [ -n "$NOTES" ]; then
    notes_json=$(printf '%s\n' "$NOTES" | jq -Rsc 'split("\n") | map(select(length > 0))')
  else
    notes_json='[]'
  fi
  if [ "$DRY_RUN" -eq 1 ]; then
    status="dry-run"
  else
    status="installed"
  fi
  jq -n \
    --arg status "$status" \
    --arg pack "$PACK" \
    --arg game "$GAME_NAME" \
    --arg gameDir "$GAME_DIR" \
    --arg loader "$LOADER" \
    --argjson wrote "$WROTE" \
    --argjson removed "$REMOVED" \
    --argjson skipped "$SKIPPED" \
    --argjson notes "$notes_json" \
    '{status: $status, pack: $pack, game: $game, gameDir: $gameDir,
      loader: $loader, wrote: $wrote, removed: $removed, skipped: $skipped,
      notes: $notes}'
fi
