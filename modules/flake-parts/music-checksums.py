#!/usr/bin/env python3
"""Generate a playlist's checksums.json from its songs.toml declaration.

Usage: music-checksums.py <playlist-dir>

Reads <dir>/songs.toml, downloads each song, and writes <dir>/checksums.json
as JSON of the form:

    { "<key>": { "url": <url>, "sha256": "sha256-<base64>" } }

— the exact format `playlist-builder.nix` feeds to fixed-output derivations,
byte-identical in shape to a packwiz checksums.json.

Two song sources (from songs.toml `source = "direct" | "yt-dlp"`):
  - direct : the URL is a byte-stable direct file (archive.org, jamendo, …).
             We download it here to hash it; Nix later fetchurl's the SAME URL.
  - yt-dlp : the URL is a watch page (YouTube, …). We run yt-dlp with the
             song's pinned format/extractorArgs to produce the exact bytes
             Nix's fixed-output derivation will produce later — so the hash
             pins bytes, not just a URL. If the source re-encodes, the Nix
             build fails with a hash mismatch; regenerate with this script.

Run as a Nix app (`nix run .#music-checksums-<name>`) at RUNTIME — download
happens then, not at eval or build time, so `nix flake check` stays green.
The app runs from the repo root and writes into the live working tree so the
file can be committed.
"""
import sys
import os
import re
import json
import hashlib
import base64
import subprocess
import tempfile
import urllib.request

try:
    import tomllib  # python 3.11+
except ModuleNotFoundError:  # pragma: no cover
    import tomli as tomllib  # type: ignore  # python 3.10 fallback


def sha256_sri(data: bytes) -> str:
    return "sha256-" + base64.b64encode(hashlib.sha256(data).digest()).decode()


def download_direct(url: str, timeout: int = 180) -> bytes:
    """Byte-stable direct URL → raw bytes."""
    with urllib.request.urlopen(url, timeout=timeout) as resp:
        return resp.read()


def download_ytdlp(url: str, fmt: str = "ba[ext=m4a]", extractor_args: str | None = None) -> bytes:
    """Run yt-dlp exactly the way playlist-builder.nix will, return the bytes."""
    with tempfile.TemporaryDirectory() as tmp:
        out = os.path.join(tmp, "song.%(ext)s")
        cmd = [
            "yt-dlp", "--no-playlist", "--no-mtime", "--ignore-config",
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


def main() -> None:
    if len(sys.argv) != 2:
        print(__doc__)
        sys.exit(1)
    pdir = sys.argv[1]
    st = os.path.join(pdir, "songs.toml")
    if not os.path.isfile(st):
        print(f"music-checksums: no songs.toml in {pdir}", file=sys.stderr)
        sys.exit(1)

    with open(st, "rb") as fh:
        songs_toml = tomllib.load(fh)
    source = songs_toml.get("source", "direct")
    result = {}
    errors = []

    for song in songs_toml.get("songs", []):
        key = song.get("key")
        url = song.get("url")
        if not key or not url:
            errors.append(f"{song}: missing key or url")
            continue
        try:
            if source == "direct":
                data = download_direct(url)
            elif source == "yt-dlp":
                data = download_ytdlp(url, song.get("format", "ba[ext=m4a]"), song.get("extractorArgs"))
            else:
                raise ValueError(f"unknown source '{source}' (expected 'direct' or 'yt-dlp')")
            result[key] = {"url": url, "sha256": sha256_sri(data)}
        except Exception as e:  # noqa: BLE001
            errors.append(f"{key}: {e}")

    if errors:
        sys.stderr.write("music-checksums: FAILED to fetch:\n  " + "\n  ".join(errors) + "\n")
        sys.exit(1)

    with open(os.path.join(pdir, "checksums.json"), "w") as fh:
        json.dump(result, fh, indent=1)
        fh.write("\n")
    print(f"wrote {os.path.join(pdir, 'checksums.json')} — commit it and rebuild")


if __name__ == "__main__":
    main()