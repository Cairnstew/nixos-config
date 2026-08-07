{ writeShellApplication, openssh, coreutils, gnugrep, ... }:

writeShellApplication {
  name = "copy-from";

  meta = {
    description = "Fetch a file from a remote host over SSH and copy its contents to the local clipboard";
    longDescription = ''
      Fetches a remote file over SSH and copies its contents straight to your
      local clipboard, detecting the clipboard backend at runtime so the same
      command works everywhere:

        Wayland (GNOME/KDE/Hyprland/Sway on Wayland) → wl-copy
        X11 (GNOME/KDE on Xorg)                      → xclip, else xsel
        macOS                                        → pbcopy
        WSL                                           → clip.exe (Windows clipboard)
        tmux (session fallback)                      → tmux load-buffer

      Set COPY_FROM_BACKEND or pass --backend to force a specific one.

      Usage:
        copy-from server /tmp/opencode/opencode-config-audit/tier0-findings.md
        copy-from seanc@server ~/.config/opencode/opencode.json
        copy-from server /path --backend xclip        # force a backend
        copy-from server /path --print                # print instead of clipboard

      Options:
        [user@]HOST     SSH host (bare hostname defaults to your local user)
        PATH            Remote path to copy
        --backend NAME  Force backend: wl-copy|xclip|xsel|pbcopy|clip.exe|tmux|print
        --print         Alias for --backend print (write contents to stdout)
        --verbose, -v   Show which target and backend are being used
        --help, -h      Show this help

      Exit codes:
        0 = copied
        1 = usage/backend error or SSH fetch failed
    '';
    homepage = "https://github.com/Cairnstew/nixos-config";
    license = "MIT";
    mainProgram = "copy-from";
  };

  runtimeInputs = [ openssh coreutils gnugrep ];

  text = ''
    set -euo pipefail

    BACKEND="auto"
    VERBOSE=false
    HOST=""
    REMOTE_PATH=""

    usage() {
      cat <<'EOF'
    Usage: copy-from [user@]HOST PATH [options]

    Fetch a file from a remote host over SSH and copy its contents to the
    local clipboard. The clipboard backend is auto-detected at runtime:

      Wayland (GNOME/KDE/Hyprland/Sway on Wayland) -> wl-copy
      X11 (GNOME/KDE on Xorg)                      -> xclip, else xsel
      macOS                                        -> pbcopy
      WSL                                           -> clip.exe (Windows clipboard)
      tmux (session fallback)                      -> tmux load-buffer

    Options:
      --backend NAME  Force backend: wl-copy|xclip|xsel|pbcopy|clip.exe|tmux|print
      --print         Alias for --backend print (write contents to stdout)
      --verbose, -v   Show which target and backend are being used
      --help, -h      Show this help

    Examples:
      copy-from server /tmp/opencode/opencode-config-audit/tier0-findings.md
      copy-from seanc@server ~/.config/opencode/opencode.json
      copy-from server /path --backend xclip
    EOF
    }

    while [ $# -gt 0 ]; do
      case "$1" in
        --backend)  BACKEND="$2"; shift 2 ;;
        --print)    BACKEND="print"; shift ;;
        --verbose|-v) VERBOSE=true; shift ;;
        --help|-h)  usage; exit 0 ;;
        -*)
          echo "Error: unknown option: $1" >&2
          usage >&2
          exit 1
          ;;
        *)
          if [ -z "$HOST" ]; then
            HOST="$1"
          elif [ -z "$REMOTE_PATH" ]; then
            REMOTE_PATH="$1"
          else
            echo "Error: too many arguments: $1" >&2
            usage >&2
            exit 1
          fi
          shift
          ;;
      esac
    done

    if [ -z "$HOST" ] || [ -z "$REMOTE_PATH" ]; then
      echo "Error: HOST and PATH are required." >&2
      usage >&2
      exit 1
    fi

    # Bare hostname -> current local user
    case "$HOST" in
      *@*) TARGET="$HOST" ;;
      *)   TARGET="$(id -un)@$HOST" ;;
    esac

    detect_backend() {
      case "$BACKEND" in
        auto) ;;
        print)
          return 0
          ;;
        wl-copy|xclip|xsel|pbcopy|clip.exe|tmux)
          if ! command -v "$BACKEND" >/dev/null 2>&1; then
            echo "Error: backend '$BACKEND' not found on PATH." >&2
            exit 1
          fi
          return 0
          ;;
        *)
          echo "Error: unknown backend '$BACKEND'." >&2
          exit 1
          ;;
      esac

      if [ "$(uname -s)" = "Darwin" ] && command -v pbcopy >/dev/null 2>&1; then
        BACKEND="pbcopy"
      elif [ -n "''${WAYLAND_DISPLAY:-}" ] && command -v wl-copy >/dev/null 2>&1; then
        BACKEND="wl-copy"
      elif [ -n "''${DISPLAY:-}" ] && command -v xclip >/dev/null 2>&1; then
        BACKEND="xclip"
      elif [ -n "''${DISPLAY:-}" ] && command -v xsel >/dev/null 2>&1; then
        BACKEND="xsel"
      elif grep -qi microsoft /proc/version 2>/dev/null && command -v clip.exe >/dev/null 2>&1; then
        BACKEND="clip.exe"
      elif [ -n "''${TMUX:-}" ] && command -v tmux >/dev/null 2>&1; then
        BACKEND="tmux"
      else
        BACKEND="print"
      fi
    }

    copy_to_clipboard() {
      case "$BACKEND" in
        wl-copy)  wl-copy >/dev/null 2>&1 ;;
        xclip)    xclip -selection clipboard >/dev/null 2>&1 ;;
        xsel)     xsel --clipboard --input >/dev/null 2>&1 ;;
        pbcopy)   pbcopy ;;
        clip.exe) clip.exe ;;
        tmux)     tmux load-buffer - ;;
        print)    cat ;;
        *)        cat ;;
      esac
    }

    detect_backend

    if $VERBOSE; then
      echo "copy-from: $TARGET:$REMOTE_PATH -> backend=$BACKEND" >&2
    fi

    # Shell-quote the remote path so spaces/special chars survive the remote login shell.
    REMOTE_CMD="cat -- $(printf '%q' "$REMOTE_PATH")"

    # REMOTE_CMD is client-side shell-quoted (printf %q), so the remote login
    # shell handles spaces/special chars safely even though ssh expands it.
    # shellcheck disable=SC2029
    ssh "$TARGET" "$REMOTE_CMD" | copy_to_clipboard
  '';
}
