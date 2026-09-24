#!/usr/bin/env python3
"""Waybar now-playing widget for Spotify.

Outputs waybar-compatible JSON with the current track info.
Requires SPOTIFY_CLIENT_ID and SPOTIFY_REDIRECT_URI in the environment
(PKCE flow — no client secret needed for user-scoped reads).

Usage (waybar custom module):
  exec = "spotify-now-playing"
  return-type = "json"
  interval = 5

Usage (interactive sign-in, from a terminal):
  spotify-now-playing --auth
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
import time
from http.server import BaseHTTPRequestHandler, HTTPServer
from threading import Thread
from urllib.parse import parse_qs, urlparse

try:
    import spotipy
    from spotipy.oauth2 import CacheFileHandler
except ImportError:
    # spotipy not available — output empty state
    print(json.dumps({"text": "♪", "tooltip": "spotipy not installed", "class": "error"}))
    sys.exit(0)


CACHE_PATH = os.environ.get(
    "SPOTIFY_CACHE_PATH",
    os.path.expanduser("~/.cache/spotify-now-playing-token"),
)

REDIRECT_URI = os.environ.get("SPOTIFY_REDIRECT_URI", "http://127.0.0.1:8877/callback")
# Shared token with spotify-click.py: the widget only displays, but the
# control buttons need user-modify-playback-state — request it here so a
# single `--auth` grants both. (Scope is fixed at authorization time, so
# re-auth is required after this scope grows.)
SCOPE = (
    "user-read-currently-playing "
    "user-read-playback-state "
    "user-modify-playback-state"
)


def make_auth_manager() -> spotipy.SpotifyPKCE | None:
    """Build the PKCE auth manager, or None when SPOTIFY_CLIENT_ID is missing."""
    client_id = os.environ.get("SPOTIFY_CLIENT_ID", "").strip()
    if not client_id:
        return None
    return spotipy.SpotifyPKCE(
        client_id=client_id,
        redirect_uri=REDIRECT_URI,
        scope=SCOPE,
        cache_handler=CacheFileHandler(cache_path=CACHE_PATH),
        open_browser=False,
    )


def get_spotify_client() -> spotipy.Spotify | None:
    """Build an authenticated Spotify client from the cached token, or None."""
    auth_manager = make_auth_manager()
    if auth_manager is None:
        return None
    try:
        # With a cached (possibly expired) token Spotipy refreshes it here.
        return spotipy.Spotify(auth_manager=auth_manager)
    except Exception:
        return None


def _wait_for_callback_code(port: int, timeout: float = 120.0) -> str | None:
    """Serve the OAuth redirect URI until the browser returns ?code=..., or timeout."""
    captured: dict[str, str] = {}
    path = urlparse(REDIRECT_URI).path or "/callback"

    class Handler(BaseHTTPRequestHandler):
        def do_GET(self):
            qs = parse_qs(urlparse(self.path).query)
            code = qs.get("code")
            if code:
                captured["code"] = code[0]
                self.send_response(200)
                self.send_header("Content-Type", "text/html; charset=utf-8")
                self.send_header("Content-Length", "42")
                self.end_headers()
                self.wfile.write("<h1>Authorized — close this tab.</h1>".encode())
            else:
                self.send_response(404)
                self.end_headers()

        def log_message(self, *args):  # silence request logs
            pass

    server = HTTPServer(("127.0.0.1", port), Handler)
    server.timeout = 1.0
    try:
        deadline = time.time() + timeout
        while time.time() < deadline:
            server.handle_request()
            if "code" in captured:
                return captured["code"]
    except OSError:
        return None
    finally:
        server.server_close()
    return None


def _open_browser(url: str) -> bool:
    """Open url in a browser by absolute profile path, falling back to webbrowser.

    The flow usually runs inside a terminal launched from waybar, whose PATH has
    no profile dir. webbrowser.open must NOT be tried first here: on a headless
    PATH it 'succeeds' by spawning xdg-open, which then fails internally and
    prints a wall of 'command not found' — so probe the home-profile browsers
    (firefox etc.) directly and only fall back to webbrowser.
    """
    import getpass

    user = getpass.getuser()
    for name in ("firefox", "brave", "chromium", "google-chrome-stable", "google-chrome", "zen"):
        path = f"/etc/profiles/per-user/{user}/bin/{name}"
        if os.path.exists(path):
            try:
                subprocess.Popen([path, url])
                return True
            except Exception:
                continue
    try:
        import webbrowser

        if webbrowser.open(url):
            return True
    except Exception:
        pass
    return False


def do_auth() -> int:
    """Run the interactive PKCE sign-in and cache the token."""
    auth_manager = make_auth_manager()
    if auth_manager is None:
        print(
            "SPOTIFY_CLIENT_ID is not set — run `spotify-now-playing --auth` "
            "(the wrapper, which exports it from the creds file), not the raw script.",
            file=sys.stderr,
        )
        return 1

    auth_url = auth_manager.get_authorize_url()
    port = urlparse(REDIRECT_URI).port or 8877

    print("\n== Spotify authorization ==")
    print("1. Open this URL in your browser and authorize:")
    print("   " + auth_url)
    if not _open_browser(auth_url):
        print("   (could not auto-open a browser — open the URL manually)")

    print(f"2. Waiting for the callback on {REDIRECT_URI} (up to 2 min)…")
    code = _wait_for_callback_code(port)
    if code is None:
        print("\nTimed out waiting for the browser callback.", file=sys.stderr)
        return 1

    try:
        auth_manager.get_access_token(code)
    except Exception as exc:
        print(f"\nAuth failed: {exc}", file=sys.stderr)
        return 1

    print("\nAuthenticated. Token cached at " + CACHE_PATH)
    return 0


def format_duration(ms: int) -> str:
    """Format milliseconds as M:SS."""
    if ms <= 0:
        return "0:00"
    total_sec = ms // 1000
    minutes = total_sec // 60
    seconds = total_sec % 60
    return f"{minutes}:{seconds:02d}"


def get_now_playing(sp: spotipy.Spotify) -> dict | None:
    """Fetch current playback and return waybar JSON dict, or None."""
    try:
        current = sp.current_playback()
    except Exception:
        return None

    if not current or not current.get("item"):
        return None

    item = current["item"]
    track_name = item.get("name", "Unknown")
    artists = ", ".join(a.get("name", "") for a in item.get("artists", []))
    album = item.get("album", {}).get("name", "")
    is_playing = current.get("is_playing", False)
    progress_ms = current.get("progress_ms", 0)
    duration_ms = item.get("duration_ms", 0)
    device = current.get("device", {}).get("name", "")

    state = "▶" if is_playing else "⏸"
    text = f" {artists} — {track_name}"

    tooltip_lines = [
        f"<b>{track_name}</b>",
        f"<i>{artists}</i>",
        album,
        f"{format_duration(progress_ms)} / {format_duration(duration_ms)}",
    ]
    if device:
        tooltip_lines.append(f"on {device}")
    tooltip = "\n".join(tooltip_lines)

    css_class = "playing" if is_playing else "paused"

    return {
        "text": text,
        "tooltip": tooltip,
        "class": css_class,
    }


def main() -> None:
    if "--auth" in sys.argv[1:]:
        sys.exit(do_auth())

    sp = get_spotify_client()
    if sp is None:
        # Visible (non-blank) placeholder so the widget shows up and is
        # clickable even before OAuth — a " " text renders as nothing.
        print(json.dumps(
            {"text": "♪", "tooltip": "Spotify — not signed in (click to sign in)", "class": "error"}
        ))
        return

    result = get_now_playing(sp)
    if result is None:
        print(json.dumps({"text": "♪", "tooltip": "Nothing playing", "class": "idle"}))
    else:
        print(json.dumps(result))


if __name__ == "__main__":
    main()