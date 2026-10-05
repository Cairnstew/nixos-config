#!/usr/bin/env python3
"""
thunderstore-checksums.py — download and pin every package a pack needs.

Run from the repo root:

    nix run .#thunderstore-checksums -- <pack>          # download + write checksums.json
    nix run .#thunderstore-checksums -- <pack> --check  # verify pins, write nothing (CI)
    nix run .#thunderstore-checksums -- <pack> --refresh

ThunderStore publishes no checksum for a package zip: the CDN serves an S3
multipart ETag (`"…-44"`), which is not a content digest. The listing *blobs*
are content-addressed (their CDN path contains the real sha256), but the mod zips
are not. So this tool is what turns a pack declaration into a reproducible Nix
build: it downloads each zip once, hashes the bytes, and commits the pin.

What ends up in checksums.json — one entry per declared mod AND per transitive
dependency, so the Nix build never has to resolve the graph:

    "<ns>-<name>-<version>": {
      "url": "...", "sha256": "sha256-<base64>", "sha256Hex": "...",
      "namespace": "...", "name": "...", "version": "...",
      "dependencies": ["<ns>-<name>-<version>", ...],
      "isLoader": false, "requestedAs": "...", "fileSize": 1234
    }

ThunderStore dependencies are `<namespace>-<name>-<version>` strings, and both
halves may contain `-`/`_`, so they cannot be split naively — resolution matches
the tail as a version against the package's own version list instead.
"""

from __future__ import annotations

import argparse
import base64
import concurrent.futures
import importlib.util
import json
import os
import sys
from typing import Any, Dict, List, Tuple

HERE = os.path.dirname(os.path.abspath(__file__))
# Under `nix run` the script lives alone in the store, so the repo-relative
# default is wrong; the Nix wrapper exports THUNDERSTORE_PACKS_DIR. Invoked from a
# checkout (or a dev shell) the default below finds the packs.
REPO_ROOT = os.path.dirname(os.path.dirname(HERE))
PACKS_ROOT = os.environ.get("THUNDERSTORE_PACKS_DIR") or os.path.join(
    REPO_ROOT, "modules", "home", "thunderstore", "packs"
)


def load_api() -> Any:
    # Under `nix run` this script lives alone in the store, so the Nix wrapper
    # points at the API module through THUNDERSTORE_API; invoked straight from
    # the repo (or from a dev shell) it is a sibling file.
    path = os.environ.get("THUNDERSTORE_API") or os.path.join(HERE, "thunderstore-api.py")
    if not os.path.exists(path):
        raise SystemExit(
            f"thunderstore: cannot find thunderstore-api.py (looked at {path}); "
            f"run this through `nix run .#thunderstore-<tool>` so the wrapper can "
            f"point THUNDERSTORE_API at the store copy"
        )
    spec = importlib.util.spec_from_file_location("thunderstore_api", path)
    if spec is None or spec.loader is None:
        raise SystemExit(f"thunderstore: cannot import {path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def live_packs_root() -> str:
    """Pins are written into the LIVE working tree, never into the read-only flake
    snapshot the Nix wrapper runs from. When invoked from the repo root, prefer
    $PWD; otherwise fall back to THUNDERSTORE_PACKS_DIR / the repo-relative path.
    """
    cwd = os.getcwd()
    if os.path.isfile(os.path.join(cwd, "flake.nix")):
        return os.path.join(cwd, "modules", "home", "thunderstore", "packs")
    return PACKS_ROOT


def resolve_pack_dir(pack: str) -> str:
    if os.path.isdir(pack):
        return os.path.abspath(pack)
    candidate = os.path.join(live_packs_root(), pack)
    if os.path.isdir(candidate):
        return candidate
    raise SystemExit(
        f"thunderstore-checksums: no pack dir for {pack!r} "
        f"(looked at {pack} and {candidate})"
    )


def read_json(path: str) -> Dict[str, Any]:
    if not os.path.exists(path):
        return {}
    with open(path) as fh:
        return json.load(fh)


def main(argv: List[str]) -> int:
    ap = argparse.ArgumentParser(
        prog="thunderstore-checksums",
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    ap.add_argument("pack", help="pack name under modules/home/thunderstore/packs/, or a path")
    ap.add_argument("--check", action="store_true", help="verify existing pins, write nothing")
    ap.add_argument("--refresh", action="store_true", help="bypass the HTTP cache")
    ap.add_argument("--jobs", type=int, default=8, help="parallel downloads (default 8)")
    args = ap.parse_args(argv)

    ts = load_api()
    pack_dir = resolve_pack_dir(args.pack)
    pack = read_json(os.path.join(pack_dir, "pack.json"))
    game = read_json(os.path.join(pack_dir, "game.json"))
    existing = read_json(os.path.join(pack_dir, "checksums.json"))

    if not pack:
        raise SystemExit(f"thunderstore-checksums: {pack_dir}/pack.json is missing or empty")
    if not game:
        raise SystemExit(
            f"thunderstore-checksums: {pack_dir}/game.json is missing — run "
            f"`nix run .#thunderstore-sync -- {os.path.basename(pack_dir)}` first "
            f"(the loader pack and autolist come from the ecosystem schema)."
        )

    community = game.get("community") or pack.get("game")
    model = game.get("model") or {}
    declared: Dict[str, str] = dict(pack.get("mods") or {})
    exclude = set(pack.get("exclude") or [])

    loader_package = None
    if model.get("installLoader") and model.get("loaderPackage"):
        loader_package = f"{model['loaderPackage']}-{model['loaderVersion']}"

    print(f"thunderstore-checksums: pack {pack.get('name')} in community {community!r}")
    print(f"  declared mods:   {len(declared)}")
    print(f"  excluded:        {', '.join(sorted(exclude)) or '(none)'}")
    print(f"  loader pack:     {loader_package or '(managed outside this pack)'}")

    if not declared and not loader_package:
        raise SystemExit(
            f"thunderstore-checksums: pack {pack.get('name')} has nothing to pin — "
            f"add mods to pack.json, or set installLoader/game.json"
        )

    resolution = ts.resolve_pack(
        community,
        declared,
        include_loader=model.get("loaderPackage") if model.get("installLoader") else None,
        skip=exclude,
        refresh=args.refresh,
    )
    pins: Dict[str, Dict[str, Any]] = resolution["pins"]
    unresolved: List[str] = resolution["unresolved"]

    if loader_package and loader_package not in pins:
        # A loader pin may legitimately be absent when the pack is excluded or the
        # autolist package is not listed; surface it rather than building blind.
        print(f"  note:            loader pack {loader_package} was not resolved")

    print(f"  resolved:        {len(pins)} package(s) including dependencies")
    for key in resolution.get("loaderDepVersionsSkipped") or []:
        print(f"    note:            {key} is a loader dependency; skipped (we pin one loader)")
    for entry in pins.values():
        if not entry["isLoader"] and entry["requestedAs"] not in declared:
            print(f"    dep  {entry['id']}")
    for problem in unresolved:
        print(f"  unresolved:      {problem}")

    if not pins:
        raise SystemExit("thunderstore-checksums: nothing resolved — refusing to write an empty pin file")

    # ── download + hash ──────────────────────────────────────────────────────
    to_fetch: List[Tuple[str, Dict[str, Any]]] = [
        (
            key,
            {
                **entry,
                # An existing pin for the same URL is verified, not replaced.
                "cached": bool(existing.get(key, {}).get("sha256"))
                and existing[key]["url"] == entry["url"],
            },
        )
        for key, entry in pins.items()
    ]

    result: Dict[str, Dict[str, Any]] = {}
    mismatches: List[str] = []
    fetched_bytes = 0

    def fetch(item: Tuple[str, Dict[str, Any]]) -> Tuple[str, Dict[str, Any]]:
        key, entry = item
        old = existing.get(key)
        if entry["cached"] and old and old.get("sha256"):
            # --check still verifies the pin against the live bytes.
            data = ts.http_get(entry["url"], refresh=args.refresh)
            digest = ts.sha256_sri(data)
            if digest != old["sha256"]:
                return key, {**entry, "mismatch": True, "actual": digest, "size": len(data)}
            return key, {**entry, "size": len(data), "verified": True}
        data = ts.http_get(entry["url"], refresh=args.refresh)
        digest = ts.sha256_sri(data)
        if old and old.get("sha256") and digest != old["sha256"]:
            return key, {**entry, "mismatch": True, "actual": digest, "size": len(data)}
        return key, {**entry, "sha256": digest, "size": len(data)}

    with concurrent.futures.ThreadPoolExecutor(max_workers=max(1, args.jobs)) as pool:
        for key, entry in pool.map(fetch, to_fetch):
            result[key] = entry
            fetched_bytes += entry.get("size") or 0
            state = (
                "MISMATCH" if entry.get("mismatch")
                else "verified" if entry.get("verified")
                else "pinned"
            )
            print(f"    {state:9s} {key:48s} {entry.get('size') or 0:>10,} B")

    for key, entry in result.items():
        if entry.get("mismatch"):
            mismatches.append(
                f"{key}: pinned {existing[key]['sha256']} but upstream now serves "
                f"{entry['actual']} — the package was re-uploaded under the same version"
            )

    out: Dict[str, Dict[str, Any]] = {}
    for key, entry in sorted(result.items()):
        if entry.get("mismatch"):
            continue
        sha = entry.get("sha256") or existing[key]["sha256"]
        out[key] = {
            "url": entry["url"],
            "sha256": sha,
            "sha256Hex": base64.b64decode(sha.split("-", 1)[1]).hex(),
            "namespace": entry["namespace"],
            "name": entry["name"],
            "version": entry["version"],
            "id": key,
            "dependencies": entry.get("dependencies") or [],
            "isLoader": bool(entry.get("isLoader")),
            "requestedAs": entry.get("requestedAs"),
            "fileSize": entry.get("fileSize"),
            "description": (entry.get("description") or "")[:200],
        }

    print(f"\n  total:          {len(out)} pin(s), {fetched_bytes:,} bytes downloaded")

    if mismatches:
        print("\n  UPSTREAM CHANGED BYTES:")
        for problem in mismatches:
            print(f"    {problem}")
        print("  A ThunderStore version is immutable upstream, so this means the pin was")
        print("  wrong or a mirror is serving different content. Investigate before")
        print("  re-pinning; delete the entry from checksums.json to force a re-pin.")

    dropped = sorted(set(existing) - set(out))
    if dropped:
        print(f"  dropped:        {len(dropped)} stale pin(s): {', '.join(dropped[:5])}")

    path = os.path.join(pack_dir, "checksums.json")
    if args.check:
        changed = [k for k, v in out.items() if existing.get(k, {}).get("sha256") != v["sha256"]]
        if changed or dropped or mismatches:
            print(f"\n  CHECK FAILED: {len(changed)} changed pin(s), {len(dropped)} dropped, "
                  f"{len(mismatches)} mismatch(es)")
            for key in changed[:10]:
                print(f"    {key}: {existing.get(key, {}).get('sha256')} -> {out[key]['sha256']}")
            return 1
        print("\n  CHECK OK: every pin matches upstream")
        return 0

    with open(path, "w") as fh:
        fh.write(json.dumps(out, indent=2, sort_keys=True, ensure_ascii=False) + "\n")
    print(f"  wrote {path}")
    if not mismatches and not unresolved:
        print(f"\nVerify the pinned bytes build:\n  nix build .#thunderstore-pack-{pack.get('name')}")
    return 1 if mismatches else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))