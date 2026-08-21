#!/usr/bin/env python3
"""Create/update a playlist's songs.toml from a PUBLIC Spotify playlist.

Usage:
    music-spotify-sync.py <playlist-dir> <spotify-url> [--client-id ID] [--client-secret SECRET] [--prune]

Design (validated 2026-08-20 on spotdl 4.5.0 + Spotify Web API):
  - Public playlists are readable with a *client-credentials* token — NO user
    OAuth needed. We use spotdl's bundled public client credentials by default
    (read-only, fine for public playlists); pass your own --client-id/--secret
    (or the future OAuth flow) if you want private playlists / Liked Songs.
  - For each Spotify track we resolve a CONCRETE YouTube watch URL via yt-dlp
    (ISRC search first — exact match — then "<artist> - <title>"). This is the
    only best-effort step: the resolution happens ONCE here and is pinned by
    the committed checksums.json, so later builds re-verify the SAME bytes.
  - Re-running is idempotent and incremental: entries already in songs.toml
    (matched by Spotify track id) are kept byte-identical; only NEW tracks are
    resolved. --prune drops tracks no longer in the upstream playlist.

Workflow (via the flake app):
    nix run .#music-spotify-sync -- <name> <spotify-url>
    #   fetch playlist -> write songs.toml -> regenerate checksums.json
    git add ... && git commit   # repo snapshot is now the reproducible truth
"""
import argparse
import json
import os
import re
import subprocess
import sys
import time
import urllib.request
import urllib.parse
import urllib.error

# spotdl's bundled public client credentials (read-only, used for public playlists).
# From spotdl 4.5.0 utils/config.py DEFAULT_CONFIG. Replaceable via --client-id/secret
# or by persisting your own Spotify API app creds.
BUNDLED_CLIENT_ID = "5f573c9620494bae87890c0f08a60293"
BUNDLED_CLIENT_SECRET = "212476d9b0f3472eaa762d90b19b0ba8"

TOKEN_URL = "https://accounts.spotify.com/api/token"
API = "https://api.spotify.com/v1"
YOUTUBE_URL = "https://www.youtube.com/watch?v={id}"


def get_token(client_id: str, client_secret: str) -> str:
    data = urllib.parse.urlencode({
        "grant_type": "client_credentials",
        "client_id": client_id,
        "client_secret": client_secret,
    }).encode()
    req = urllib.request.Request(TOKEN_URL, data=data)
    with urllib.request.urlopen(req, timeout=30) as resp:
        return json.load(resp)["access_token"]


def api_get(path: str, params: dict, retries: int = 4) -> dict:
    """GET a Spotify API endpoint with backoff on 429/5xx.

    Uses the module-global token (see get_token_from_env_or_bundled) and
    refreshes it on a 401 or after a 429 so retries use a fresh token.
    """
    query = urllib.parse.urlencode(params)
    url = f"{API}/{path}?{query}"
    for attempt in range(retries):
        req = urllib.request.Request(url, headers={"Authorization": f"Bearer {get_token_from_env_or_bundled()}"})
        try:
            with urllib.request.urlopen(req, timeout=30) as resp:
                return json.load(resp)
        except urllib.error.HTTPError as e:
            if e.code in (429, 500, 502, 503):
                try:
                    wait = float(e.headers.get("Retry-After", 0) or 0)
                except ValueError:
                    wait = 0
                wait = max(min(wait, 20), 2 ** attempt)
                sys.stderr.write(f"  api {e.code}, waiting {wait:.0f}s then retrying ...\n")
                time.sleep(wait)
                reset_token()
                continue
            if e.code == 401:
                reset_token()
                continue
            raise
    raise RuntimeError(f"Spotify API persistently failed for {path} (rate-limited or playlist not public?)")


def fetch_playlist_tracks(playlist_id: str, token: str) -> list[dict]:
    """All tracks of a public playlist (paginated)."""
    tracks = []
    offset = 0
    while True:
        data = api_get(f"playlists/{playlist_id}/tracks", {
            "limit": 100,
            "offset": offset,
            "fields": "total,items(track(id,name,artists(name),duration_ms,external_ids,is_local))",
        })
        total = data.get("total", 0)
        for item in data.get("items", []):
            t = item.get("track")
            if not t or t.get("is_local"):
                continue  # skip local files / unavailable tracks
            tracks.append({
                "id": t["id"],
                "name": t["name"],
                "artists": [a["name"] for a in t.get("artists", [])],
                "duration_ms": t.get("duration_ms", 0),
                "isrc": (t.get("external_ids") or {}).get("isrc"),
            })
        offset += len(data.get("items", []))
        if offset >= total or not data.get("items"):
            break
    return tracks


_tok = None


def get_token_from_env_or_bundled():
    global _tok
    cid = os.environ.get("SPOTIFY_CLIENT_ID") or BUNDLED_CLIENT_ID
    sec = os.environ.get("SPOTIFY_CLIENT_SECRET") or BUNDLED_CLIENT_SECRET
    if _tok is None:
        _tok = get_token(cid, sec)
    return _tok


def reset_token():
    """Force the next API call to mint a fresh token."""
    global _tok
    _tok = None


def resolve_youtube_url(track: dict) -> str | None:
    """Resolve a Spotify track to a concrete YouTube watch URL via yt-dlp.

    ISRC search first (exact release), then "<artist> - <title>". Returns None
    if no stable match could be found (caller drops the track loudly).
    """
    queries = []
    if track.get("isrc"):
        queries.append(f"ytsearch1:{track['isrc']}")
    query = f"{' '.join(track['artists'])} - {track['name']}"
    queries.append(f"ytsearch1:{query}")

    for q in queries:
        try:
            out = subprocess.run(
                ["yt-dlp", "--get-id", "--no-warnings", "--skip-download", "--no-update",
                 "--extractor-args", "youtube:player_client=web_embedded", q],
                capture_output=True, text=True, timeout=90,
            )
            vid = out.stdout.strip()
            if re.fullmatch(r"[A-Za-z0-9_-]{6,}", vid):
                return YOUTUBE_URL.format(id=vid)
        except (subprocess.TimeoutExpired, subprocess.CalledProcessError) as e:
            sys.stderr.write(f"  resolve failed for {track['name']}: {e}\n")
    return None


def parse_spotify_url(url: str) -> str:
    m = re.search(r"(?:playlist|artist|album|track)/([A-Za-z0-9]+)", url)
    if not m:
        raise SystemExit(f"not a Spotify URL: {url}")
    return m.group(1)


def title_of(s: dict) -> str:
    t = s.get("title")
    if t:
        return t
    if s.get("name"):
        return s["name"].replace('"', "")
    return s.get("key", "unknown")


def write_songs_toml(dir_path: str, name: str, songs: list[dict]):
    """Write songs.toml for a yt-dlp-source playlist (schema of playlist-builder.nix)."""
    chunks = [
        "".join([
            f'key = "{s["key"]}"\n',
            f'url = "{s["url"]}"\n',
            f'format = "ba[ext=m4a]"\n',
            f'title = "{title_of(s)}"\n',
        ])
        for s in songs
    ]
    lines = [
        f'name = "{name}"',
        'source = "yt-dlp"',
        "",
        "[[songs]]",
        "\n[[songs]]\n".join(chunks),
    ]
    with open(os.path.join(dir_path, "songs.toml"), "w") as fh:
        fh.write("\n".join(lines) + "\n")


def load_existing(dir_path: str) -> dict:
    """Existing songs.toml mapped by spotify key (key == spotify track id)."""
    path = os.path.join(dir_path, "songs.toml")
    if not os.path.exists(path):
        return {}
    try:
        import tomllib
    except ImportError:  # pragma: no cover
        import tomli as tomllib  # type: ignore
    with open(path, "rb") as fh:
        data = tomllib.load(fh)
    return {s.get("key"): s for s in data.get("songs", [])}


def load_csv_tracks(csv_path: str) -> list[dict]:
    """Parse a Spotify "Your Library" CSV export into {id, name, artists, isrc}.

    Expects columns 'Spotify - id', 'Track name', 'Artist name', 'ISRC'
    (the first-column header may carry a UTF-8 BOM, which we strip). Tracks
    without a Spotify id are skipped.
    """
    import csv

    with open(csv_path, encoding="utf-8-sig") as fh:
        reader = csv.DictReader(fh)
        tracks = []
        for r in reader:
            sid = (r.get("Spotify - id") or "").strip()
            if not sid:
                continue
            tracks.append({
                "id": sid,
                "name": (r.get("Track name") or r.get("\ufeffTrack name") or "").strip(),
                "artists": [a.strip() for a in (r.get("Artist name") or "").split(",") if a.strip()],
                "isrc": (r.get("ISRC") or "").strip() or None,
            })
        return tracks


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("playlist_dir")
    ap.add_argument("spotify_url", nargs="?", default=None,
                    help="public Spotify playlist URL (mutually exclusive with --csv)")
    ap.add_argument("--csv", default=None,
                    help="path to a Spotify 'Your Library' CSV export to bootstrap from")
    ap.add_argument("--client-id", default=None)
    ap.add_argument("--client-secret", default=None)
    ap.add_argument("--prune", action="store_true", help="drop songs no longer in the playlist")
    args = ap.parse_args()

    if not os.path.isdir(args.playlist_dir):
        raise SystemExit(f"no playlist dir: {args.playlist_dir}")
    if bool(args.spotify_url) == bool(args.csv):
        raise SystemExit("provide exactly one of a Spotify playlist URL or --csv FILE")

    os.environ.setdefault("SPOTIFY_CLIENT_ID", args.client_id or "")
    os.environ.setdefault("SPOTIFY_CLIENT_SECRET", args.client_secret or "")

    if args.csv:
        if not os.path.isfile(args.csv):
            raise SystemExit(f"no CSV file: {args.csv}")
        print(f"Loading {args.csv} ...")
        tracks = load_csv_tracks(args.csv)
        if not tracks:
            raise SystemExit("CSV produced no tracks (no 'Spotify - id' rows?)")
        print(f"  {len(tracks)} tracks from CSV")
    else:
        print(f"Fetching {args.spotify_url} ...")
        pid = parse_spotify_url(args.spotify_url)
        tracks = fetch_playlist_tracks(pid, get_token_from_env_or_bundled())
        if not tracks:
            raise SystemExit("playlist returned no tracks — is it PUBLIC? (client-credentials only sees public playlists)")
        print(f"  {len(tracks)} tracks in upstream playlist")
        if not args.client_id:
            print("  (using spotdl's bundled public client credentials — enough for public playlists)")

    existing = load_existing(args.playlist_dir)

    # Merge: keep existing entries by spotify key, resolve only new tracks.
    # Also re-verify existing entries still resolve (a CSV re-run refreshes the
    # source-of-truth list); --prune drops what's no longer listed.
    new_songs = []
    kept = dropped = resolved = 0
    for t in tracks:
        key = t["id"]
        if key in existing and existing[key].get("url"):
            keep = dict(existing[key])
            keep["key"] = key
            new_songs.append(keep)
            kept += 1
            continue
        url = resolve_youtube_url(t)
        if not url:
            sys.stderr.write(f"  DROPPING (no stable youtube match): {t['artists']} - {t['name']}\n")
            dropped += 1
            continue
        new_songs.append({
            "key": key,
            "url": url,
            "title": f"{' '.join(t['artists'])} - {t['name']}",
        })
        resolved += 1
        time.sleep(0.5)  # gentle rate limit for youtube resolution

    if args.prune:
        upstream = {t["id"] for t in tracks}
        new_songs = [s for s in new_songs if s["key"] in upstream]
        print(f"  pruned to {len(new_songs)} songs (wanted {len(upstream)})")

    playlist_name = os.path.basename(os.path.normpath(args.playlist_dir))
    write_songs_toml(args.playlist_dir, playlist_name, new_songs)

    print(f"  kept {kept}, resolved {resolved} new, dropped {dropped}")
    print(f"wrote {os.path.join(args.playlist_dir, 'songs.toml')}")
    print("Next: regenerate checksums (nix run .#music-checksums-<name>) and commit.")


if __name__ == "__main__":
    main()