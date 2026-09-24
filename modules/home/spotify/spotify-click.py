#!/usr/bin/env python3
"""Click handler for the Spotify now-playing waybar widget.

With a control argument (previous | toggle | next), controls Spotify via the
Spotify Web API (the same PKCE token the widget uses) — this affects ONLY the
Spotify account's active device, never other media players. With no argument,
falls back to the old behaviour:
  - not authenticated → open a terminal running `spotify-now-playing --auth`
    so the PKCE OAuth flow can complete (the browser is opened from there).
  - authenticated → open the Spotify desktop app.
"""

import getpass
import os
import subprocess
import sys

try:
    import spotipy
    from spotipy.oauth2 import CacheFileHandler
except ImportError:
    # spotipy not available — try to open the Spotify website directly
    subprocess.Popen(["xdg-open", "https://open.spotify.com"])
    sys.exit(0)

CACHE_PATH = os.environ.get(
    "SPOTIFY_CACHE_PATH",
    os.path.expanduser("~/.cache/spotify-now-playing-token"),
)

REDIRECT_URI = os.environ.get("SPOTIFY_REDIRECT_URI", "http://127.0.0.1:8877/callback")

# Shared with now-playing-waybar.py: the widget displays with the read scopes,
# but playback control needs user-modify-playback-state, and scope is fixed at
# authorization time — so re-running `spotify-now-playing --auth` after this
# scope change is required for the control buttons to work.
SCOPE = (
    "user-read-currently-playing "
    "user-read-playback-state "
    "user-modify-playback-state"
)


def profile_bin(exe: str) -> str:
    """Resolve a home-manager bin by profile path (waybar's PATH has no profile dir)."""
    return f"/etc/profiles/per-user/{getpass.getuser()}/bin/{exe}"


def is_authenticated() -> bool:
    """Check if we have a valid cached token."""
    client_id = os.environ.get("SPOTIFY_CLIENT_ID", "").strip()
    if not client_id:
        return False
    try:
        cache = CacheFileHandler(cache_path=CACHE_PATH)
        return cache.get_cached_token() is not None
    except Exception:
        return False


def open_in_terminal(command: list[str]) -> bool:
    """Launch `command` in a terminal found via the home profile bin. Returns True on success."""
    terminals = [("ghostty", "-e"), ("kitty", "-e"), ("alacritty", "-e"), ("xterm", "-e")]
    for term, flag in terminals:
        path = profile_bin(term)
        if os.path.exists(path):
            subprocess.Popen([path, flag, *command])
            return True
    return False


def control_spotify(action: str) -> int:
    """Control ONLY Spotify via the Web API. Returns 0 on success, 1 on failure.

    The player endpoints operate on the account's active Spotify device, so
    this never touches other media players (unlike playerctl routing which
    follows the most recently active player).
    """
    client_id = os.environ.get("SPOTIFY_CLIENT_ID", "").strip()
    if not client_id or not is_authenticated():
        print(
            "spotify-widget-click: not signed in — run `spotify-now-playing --auth` once",
            file=sys.stderr,
        )
        return 1

    auth_manager = spotipy.SpotifyPKCE(
        client_id=client_id,
        redirect_uri=REDIRECT_URI,
        scope=SCOPE,
        cache_handler=CacheFileHandler(cache_path=CACHE_PATH),
        open_browser=False,
    )
    sp = spotipy.Spotify(auth_manager=auth_manager)

    try:
        if action == "previous":
            sp.previous_track()
        elif action == "next":
            sp.next_track()
        elif action == "toggle":
            playback = sp.current_playback()
            if playback and playback.get("is_playing"):
                sp.pause_playback()
            else:
                sp.start_playback()
    except spotipy.SpotifyException as exc:
        msg = exc.msg or ""
        reason = getattr(exc, "reason", "") or ""
        lower = f"{msg} {reason}".lower()
        if "insufficient" in lower and "scope" in lower:
            print(
                "spotify-widget-click: token lacks control scope — run "
                "`spotify-now-playing --auth` to re-authorize",
                file=sys.stderr,
            )
        elif "premium" in lower:
            print(
                "spotify-widget-click: Spotify Web API playback control requires "
                "Premium",
                file=sys.stderr,
            )
        elif "device" in lower:
            print(
                "spotify-widget-click: no active Spotify device — open the "
                "Spotify app first",
                file=sys.stderr,
            )
        else:
            print(
                f"spotify-widget-click: Spotify API error (HTTP {exc.status_code}): "
                f"{msg} {reason}".strip(),
                file=sys.stderr,
            )
        return 1
    return 0


def main():
    # Inline control buttons: previous | toggle | next — Spotify Web API only.
    control = sys.argv[1] if len(sys.argv) > 1 else ""
    if control in {"previous", "toggle", "next"}:
        sys.exit(control_spotify(control))

    if not is_authenticated():
        # Real sign-in path: run the interactive PKCE flow in a terminal.
        # (The old behavior opened the developer dashboard, which can't complete OAuth.)
        cmd = [profile_bin("spotify-now-playing"), "--auth"]
        if not open_in_terminal(cmd):
            print(
                "spotify-widget-click: no terminal found — run "
                + " ".join(cmd)
                + " in a terminal to sign in",
                file=sys.stderr,
            )
    else:
        # Authenticated - open the Spotify desktop app (absolute profile path:
        # waybar's unit PATH has no profile dir).
        desktop = profile_bin("spotify")
        if os.path.exists(desktop):
            subprocess.Popen([desktop])
        else:
            print(f"spotify-widget-click: {desktop} not found", file=sys.stderr)


if __name__ == "__main__":
    main()