#!/usr/bin/env python3
"""
thunderstore-sync.py — freeze a game's ecosystem model into a pack directory.

Run from the repo root:

    nix run .#thunderstore-sync -- <pack>            # refresh game.json (+ report)
    nix run .#thunderstore-sync -- <pack> --latest   # also bump mods to newest
    nix run .#thunderstore-sync -- <pack> --dry-run  # report only, write nothing

What it does:

  1. Fetches the ecosystem schema (351 games / 307 communities) and resolves the
     pack's `game` slug + `instance` (a game can have several: Valheim ships a
     `game` and a `server` instance, each with its own install layout).
  2. Writes `game.json`: the raw ecosystem entry (so the model stays auditable
     against upstream) PLUS a flattened `model` block with everything the Nix
     build and the installer need — steam appid, steamFolderName,
     dataFolderName, exeNames, packageLoader, installRules, relativeFileExclusions,
     the community's autolistPackageIds, and the resolved loader pack with the
     `rootFolder` the loader's zip nests its payload in.
  3. Picks the loader pack: the pack's own `loaderPackage`, else the community's
     autolist package, else nothing (you then manage the loader yourself).
  4. Resolves the declared mods against the community listing, reporting missing
     ones and — with --latest — rewriting pack.json to the newest active
     versions.

It deliberately does NOT download mod zips: that is thunderstore-checksums's job,
because ThunderStore publishes no hash for them.
"""

from __future__ import annotations

import argparse
import importlib.util
import json
import os
import sys
from typing import Any, Dict, List

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
    """Packs are edited in the LIVE working tree, never in the read-only flake
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
        f"thunderstore: no pack dir for {pack!r} (looked at {pack} and {candidate})"
    )


def read_json(path: str) -> Dict[str, Any]:
    if not os.path.exists(path):
        return {}
    with open(path) as fh:
        return json.load(fh)


def write_json(path: str, payload: Dict[str, Any], dry_run: bool) -> None:
    body = json.dumps(payload, indent=2, sort_keys=True, ensure_ascii=False) + "\n"
    if dry_run:
        print(f"  would write {path} ({len(body)} bytes)")
        return
    with open(path, "w") as fh:
        fh.write(body)
    print(f"  wrote {path}")


def main(argv: List[str]) -> int:
    ap = argparse.ArgumentParser(
        prog="thunderstore-sync", description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    ap.add_argument("pack", help="pack name under modules/home/thunderstore/packs/, or a path")
    ap.add_argument("--latest", action="store_true", help="rewrite pack.json mods to newest active versions")
    ap.add_argument("--dry-run", action="store_true", help="report without writing")
    ap.add_argument("--refresh", action="store_true", help="bypass the HTTP cache")
    ap.add_argument(
        "--loader",
        help="force the loader pack, e.g. BepInEx-BepInExPack (else: autolist, else none)",
    )
    args = ap.parse_args(argv)

    ts = load_api()
    pack_dir = resolve_pack_dir(args.pack)
    pack = read_json(os.path.join(pack_dir, "pack.json"))
    if not pack:
        raise SystemExit(f"thunderstore-sync: {pack_dir}/pack.json is missing or empty")

    slug = pack.get("game")
    if not slug:
        raise SystemExit(f"thunderstore-sync: {pack_dir}/pack.json has no \"game\" slug")

    print(f"thunderstore-sync: pack {pack.get('name', os.path.basename(pack_dir))} -> game {slug!r}")
    eco = ts.fetch_ecosystem(refresh=args.refresh)
    print(f"  ecosystem schema {eco.get('schemaVersion')}: "
          f"{len(eco.get('games', {}))} games, {len(eco.get('communities', {}))} communities")

    game = ts.game_entry(eco, slug)
    idx, instance = ts.select_instance(game, pack.get("instance"))
    community = ts.community_entry(eco, slug)

    model = ts.describe_game(eco, slug)
    if pack.get("instance") not in (None, ""):
        # Re-derive for a non-default instance without mutating the shared schema.
        scoped = json.loads(json.dumps(eco))
        scoped["games"][slug]["r2modman"] = [instance]
        model = ts.describe_game(scoped, slug)

    # ── loader pack ──────────────────────────────────────────────────────────
    loader_candidates = {
        "pack.json": pack.get("loaderPackage"),
        "--loader": args.loader,
        "autolist": (model["autolistPackageIds"] or [None])[0],
    }
    loader_package = next((v for v in loader_candidates.values() if v), None)
    loader_entry = ts.modloader_package(eco, loader_package) if loader_package else None
    install_loader = pack.get("installLoader")
    if install_loader is None:
        # Autolist means "this game needs a loader"; respect it unless the user
        # explicitly opted out.
        install_loader = bool(loader_candidates["autolist"]) or bool(loader_candidates["--loader"])
    if not install_loader:
        loader_package = None
        loader_entry = None

    loader_version = pack.get("loaderVersion")
    if loader_package and not loader_version:
        listing = ts.fetch_listing(slug, refresh=args.refresh)
        pkg = listing.get(loader_package)
        if pkg is None:
            raise SystemExit(
                f"thunderstore-sync: loader pack {loader_package!r} is not listed in {slug!r}"
            )
        loader_version = ts.latest_version(pkg)["version_number"]
        print(f"  loader:         {loader_package} {loader_version} (newest; pinned into pack.json)")
    elif loader_package:
        print(f"  loader:         {loader_package} {loader_version} (from pack.json)")

    if loader_entry is None and loader_package:
        raise SystemExit(
            f"thunderstore-sync: {loader_package!r} is not in the ecosystem's "
            f"modloaderPackages registry, so its rootFolder is unknown. Game-specific "
            f"packs must be registered in ecosystem-schema games/misc/modloader-packages.yml."
        )

    model.update(
        {
            "installLoader": bool(install_loader),
            "loaderPackage": loader_package,
            "loaderVersion": loader_version,
            "loaderPackageRootFolder": (loader_entry or {}).get("rootFolder", ""),
            "loaderPackRegistry": loader_entry,
            "autolistPackageIds": model["autolistPackageIds"],
            "schemaVersion": eco.get("schemaVersion"),
        }
    )

    game_json = {
        "schemaVersion": eco.get("schemaVersion"),
        "source": ts.ECOSYSTEM_SCHEMA_URL,
        "fetchedAt": ts.time.strftime("%Y-%m-%dT%H:%M:%SZ", ts.time.gmtime()),
        "community": slug,
        "instance": pack.get("instance") or 0,
        "communityMeta": {
            "listed": community.get("listed"),
            "displayName": community.get("displayName"),
            "discordUrl": community.get("discordUrl"),
            "wikiUrl": community.get("wikiUrl"),
            "packageIndex": instance.get("packageIndex"),
        },
        "game": game,
        "model": model,
    }

    print(f"  display name:   {model['displayName']}")
    print(f"  loader:         {model['packageLoader']} (install-rule driven: "
          f"{model['loaderInstallRuleDriven']})")
    print(f"  steam appid:    {model['steamAppId'] or '(none)'}")
    print(f"  steam folder:   {model['steamFolderName']}")
    print(f"  data folder:    {model['dataFolderName']!r}")
    print(f"  exe:            {', '.join(model['exeNames']) or '(none)'}")
    print(f"  install rules:  {len(model['installRules'])}")
    if not model["installRules"] and model["loaderInstallRuleDriven"]:
        print("  WARNING: install-rule-driven loader with no installRules — "
              "no mod file could be placed")

    # ── mods ─────────────────────────────────────────────────────────────────
    declared: Dict[str, str] = dict(pack.get("mods") or {})
    new_mods: Dict[str, str] = {}
    problems: List[str] = []
    if declared:
        listing = ts.fetch_listing(slug, refresh=args.refresh)
        print(f"  mods:           {len(declared)} declared")
        for full_name, spec in sorted(declared.items()):
            pkg = listing.get(full_name)
            if pkg is None:
                problems.append(f"{full_name} is not listed in community {slug!r}")
                continue
            if pkg.get("is_deprecated"):
                problems.append(f"{full_name} is marked deprecated upstream")
            if pkg.get("has_nsfw_content"):
                problems.append(f"{full_name} is flagged NSFW")
            version = ts.find_version(pkg, spec)
            if version is None:
                problems.append(f"{full_name}@{spec}: no matching active version")
                continue
            resolved = version["version_number"]
            new_mods[full_name] = resolved
            marker = " (kept)" if spec == resolved else f" (latest: {resolved})"
            print(f"    {full_name:42s} {resolved}{marker}")

    for problem in problems:
        print(f"  problem:        {problem}")

    if args.latest and new_mods != declared:
        pack["mods"] = new_mods
        write_json(os.path.join(pack_dir, "pack.json"), pack, args.dry_run)

    if loader_package and loader_version and pack.get("loaderVersion") != loader_version:
        pack["loaderVersion"] = loader_version
        write_json(os.path.join(pack_dir, "pack.json"), pack, args.dry_run)

    write_json(os.path.join(pack_dir, "game.json"), game_json, args.dry_run)

    if not args.dry_run:
        print("\nNext: pin the bytes so the build is reproducible —")
        print(f"  nix run .#thunderstore-checksums -- {os.path.basename(pack_dir)}")

    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))