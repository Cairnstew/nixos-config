#!/usr/bin/env python3
"""Runtime downloader/installer for YT-DLP-source music playlists.

Usage:
    music-install.py <playlist-dir> <target-dir>

Runs OUTSIDE the Nix build sandbox (as a systemd oneshot), so it can reach
YouTube/Spotify the way the sandboxed FOD build cannot (the build sandbox has
no usable DNS — resolv.conf points at 127.0.0.53 — and YouTube anti-bot blocks
anonymized datacenter sandboxes). It:

  1. reads <playlist-dir>/songs.toml (keys) and <playlist-dir>/checksums.json
     (pinned url + sha256 for each key) — the reproducible declarations,
  2. for each song runs yt-dlp (web_embedded client) into a temp dir,
  3. verifies the downloaded bytes match the PINNED sha256 — a mismatch is a
     hard error (the source changed; re-run .#music-checksums-<name>),
  4. writes the verified file into <target-dir>/<key>.<ext>.

This is the yt-dlp-tier analogue of playlist-builder.nix's fixed-output
derivation for the `direct` tier. The committed checksums.json is what makes
it reproducible: the hashes are the source of truth, not the download itself.
"""
import argparse
import base64
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile


def sha256_hex_to_sri(hexdigest: str) -> str:
    return "sha256-" + base64.b64encode(bytes.fromhex(hexdigest)).decode()


def sri_matches(data: bytes, sri: str) -> bool:
    got = "sha256-" + base64.b64encode(hashlib.sha256(data).digest()).decode()
    return got == sri


def download_ytdlp(url: str, fmt: str, extractor_args: str | None) -> bytes:
    extractor_args = extractor_args or "youtube:player_client=web_embedded"
    with tempfile.TemporaryDirectory() as tmp:
        out = os.path.join(tmp, "song.%(ext)s")
        cmd = [
            "yt-dlp", "--no-playlist", "--no-mtime", "--ignore-config", "--no-update",
            "-f", fmt,
        ]
        if extractor_args:
            cmd += ["--extractor-args", extractor_args]
        cmd += ["-o", out, url]
        subprocess.run(cmd, check=True, capture_output=True)
        files = [f for f in os.listdir(tmp) if f.startswith("song.")]
        if len(files) != 1:
            raise RuntimeError(f"yt-dlp produced {len(files)} files, expected 1")
        with open(os.path.join(tmp, files[0]), "rb") as fh:
            return fh.read()


def ext_from_format(fmt: str) -> str:
    m = re.search(r"ext=([a-zA-Z0-9]+)", fmt)
    return "." + (m.group(1) if m else "m4a")


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("playlist_dir")
    ap.add_argument("target_dir")
    args = ap.parse_args()

    pdir = args.playlist_dir
    songs_toml_path = os.path.join(pdir, "songs.toml")
    checksums_path = os.path.join(pdir, "checksums.json")
    if not os.path.isfile(songs_toml_path) or not os.path.isfile(checksums_path):
        raise SystemExit(f"playlist dir missing songs.toml/checksums.json: {pdir}")

    try:
        import tomllib
    except ImportError:  # pragma: no cover
        import tomli as tomllib  # type: ignore
    with open(songs_toml_path, "rb") as fh:
        songs_toml = tomllib.load(fh)
    if songs_toml.get("source", "direct") != "yt-dlp":
        raise SystemExit(f"playlist {pdir} is not a yt-dlp-source playlist (use the FOD build / direct tier instead)")
    with open(checksums_path) as fh:
        checksums = json.load(fh)

    os.makedirs(args.target_dir, exist_ok=True)
    ok = failed = 0
    for song in songs_toml.get("songs", []):
        key = song.get("key")
        url = song.get("url")
        if not key or key not in checksums:
            print(f"  SKIP {key}: no checksum", file=sys.stderr)
            continue
        cs = checksums[key]
        fmt = song.get("format", "ba[ext=m4a]")
        try:
            print(f"  downloading {key} ...")
            data = download_ytdlp(url, fmt, song.get("extractorArgs"))
            if not sri_matches(data, cs["sha256"]):
                raise RuntimeError(
                    f"hash mismatch for {key}: source changed — re-run '.#music-checksums-' and commit"
                )
        except Exception as e:  # noqa: BLE001
            failed += 1
            print(f"  FAIL {key}: {str(e)[:200]}", file=sys.stderr)
            continue

        out_path = os.path.join(args.target_dir, f"{key}{ext_from_format(fmt)}")
        with open(out_path, "wb") as fh:
            fh.write(data)
        ok += 1
        print(f"  -> {out_path} ({len(data)} bytes, verified)")

    print(f"music-install: {ok} ok, {failed} failed -> {args.target_dir}")
    if failed:
        sys.exit(1)


if __name__ == "__main__":
    main()