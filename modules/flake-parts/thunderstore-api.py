#!/usr/bin/env python3
"""
thunderstore-api.py — shared client for the Thunderstore ecosystem + community APIs.

Used by `thunderstore-sync` and `thunderstore-checksums` (and by the
`thunderstore-game-info` app). Lives next to those scripts because they all need
the same three primitives:

  1. fetch_ecosystem()      → the whole ecosystem schema (351 games / 307
                               communities / 100 modloader packages, ~1.6 MB JSON)
                               from /api/experimental/schema/dev/latest/.
  2. fetch_listing(slug)    → every package + every version + every dependency
                               string for one community, via the *package listing
                               index* (a content-addressed chunk list on the CDN),
                               NOT /c/<slug>/api/v1/package/ which is an
                               unpaginated ~330 MB dump.
  3. resolve_version(...)   → map a package + version spec to a concrete version
                               record, and walk the `dependencies` graph.

Design notes that matter (all verified against thunderstore.io):

  * Dependency strings are `<namespace>-<name>-<version>`. Namespaces and names
    may themselves contain `-` and `_`, so the string CANNOT be split naively.
    We resolve it by matching the tail as a version against the package's own
    `versions[]`, and the head as a `full_name` from the listing index.
  * There is no endpoint for "all versions of one package" outside a community
    listing, and no published checksum for a package zip (the CDN ETag is an S3
    multipart ETag, which is not a content digest). Hashes are therefore
    computed out of band by `thunderstore-checksums` and committed.
  * The listing-index blob path embeds the sha256 of the blob, and each chunk
    URL does too, so those fetches are verifiable. Package zips are immutable
    per <ns>-<name>-<version> but must be hashed locally.
  * Cache: every HTTP GET is cached under $XDG_CACHE_HOME/thunderstore (or
    ~/.cache/thunderstore) keyed by URL. ThunderStore's CDN sets long
    max-age on the blobs, so a re-run is nearly free. `--refresh` busts it.
"""

from __future__ import annotations

import base64
import gzip
import hashlib
import json
import os
import re
import sys
import time
import urllib.error
import urllib.request
from typing import Any, Dict, Iterable, List, Optional, Tuple

# --------------------------------------------------------------------------- #
# Endpoints
# --------------------------------------------------------------------------- #

ECOSYSTEM_SCHEMA_URL = "https://thunderstore.io/api/experimental/schema/dev/latest/"
COMMUNITY_LISTING_INDEX = "https://thunderstore.io/c/{community}/api/v1/package-listing-index/"
PACKAGE_DOWNLOAD_URL = "https://thunderstore.io/package/download/{namespace}/{name}/{version}/"
COMMUNITY_PAGE = "https://thunderstore.io/c/{community}/"

USER_AGENT = "nixos-config-thunderstore/1.0 (+nix flake tooling)"

# Loaders whose mod layout is defined by hardcoded plugin installers in
# r2modmanPlus / tcli rather than by the ecosystem's `installRules`. Modelled
# here only for validation + documentation; the Nix side (`lib/loaders.nix`)
# holds the authoritative routing table.
INSTALL_RULE_DRIVEN_LOADERS = {
    "bepinex",
    "bepisloader",
    "godotml",
    "melonloader",
    "northstar",
    "shimloader",
    "umm",
}

# Loaders that hard-require a non-empty dataFolderName (ecosystem-schema
# `requiresDataFolder`).
LOADERS_REQUIRING_DATA_FOLDER = {"bepinex", "shimloader", "umm", "recursive-melonloader"}

ALL_LOADERS = {
    "bepinex",
    "melonloader",
    "northstar",
    "godotml",
    "shimloader",
    "lovely",
    "return-of-modding",
    "gdweave",
    "recursive-melonloader",
    "bepisloader",
    "umm",
    "rivet",
    "none",
}

ALL_PLATFORMS = {
    "steam",
    "steam-direct",
    "epic-games-store",
    "oculus-store",
    "origin",
    "xbox-game-pass",
    "other",
}

# Only these five are legal in `communities.<slug>.autolistPackageIds`
# (ecosystem-schema games/src/schema/autolistPackages.ts).
LEGAL_AUTOLIST_PACKAGES = {
    "BepInEx-BepInExPack",
    "BepInEx-BepInExPack_IL2CPP",
    "Thunderstore-unreal_shimloader",
    "LavaGang-MelonLoader",
    "GodotModding-GodotModLoader",
}


class ThunderstoreError(RuntimeError):
    pass


# --------------------------------------------------------------------------- #
# HTTP + cache
# --------------------------------------------------------------------------- #


def cache_dir() -> str:
    base = os.environ.get("XDG_CACHE_HOME") or os.path.expanduser("~/.cache")
    path = os.path.join(base, "thunderstore")
    os.makedirs(path, exist_ok=True)
    return path


def _cache_path(url: str) -> str:
    digest = hashlib.sha256(url.encode()).hexdigest()[:32]
    return os.path.join(cache_dir(), f"{digest}.bin")


def http_get(url: str, refresh: bool = False, retries: int = 3) -> bytes:
    """GET `url`, following redirects. Cached on disk by URL."""
    path = _cache_path(url)
    if os.path.exists(path) and not refresh:
        with open(path, "rb") as fh:
            return fh.read()

    last: Optional[Exception] = None
    for attempt in range(retries):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
            with urllib.request.urlopen(req, timeout=120) as resp:
                data = resp.read()
            break
        except (urllib.error.URLError, TimeoutError, OSError) as exc:  # pragma: no cover
            last = exc
            if attempt == retries - 1:
                raise ThunderstoreError(f"GET {url} failed: {exc}") from exc
            time.sleep(2 * (attempt + 1))
    else:  # pragma: no cover
        raise ThunderstoreError(f"GET {url} failed: {last}")

    tmp = f"{path}.tmp.{os.getpid()}"
    with open(tmp, "wb") as fh:
        fh.write(tmp) if False else fh.write(data)
    os.replace(tmp, path)
    return data


def http_get_json(url: str, refresh: bool = False) -> Any:
    raw = http_get(url, refresh=refresh)
    return json.loads(raw)


def _maybe_gunzip(data: bytes) -> bytes:
    if data[:2] == b"\x1f\x8b":
        return gzip.decompress(data)
    return data


# --------------------------------------------------------------------------- #
# Ecosystem schema
# --------------------------------------------------------------------------- #


def fetch_ecosystem(refresh: bool = False) -> Dict[str, Any]:
    """The full ecosystem schema: games / communities / modloaderPackages."""
    return http_get_json(ECOSYSTEM_SCHEMA_URL, refresh=refresh)


def game_entry(ecosystem: Dict[str, Any], slug: str) -> Dict[str, Any]:
    games = ecosystem.get("games", {})
    if slug not in games:
        raise ThunderstoreError(
            f"game {slug!r} is not in the ecosystem schema "
            f"({len(games)} games known). Try `nix run .#thunderstore-game-info -- --list | grep {slug}`."
        )
    return games[slug]


def community_entry(ecosystem: Dict[str, Any], slug: str) -> Dict[str, Any]:
    return ecosystem.get("communities", {}).get(slug, {})


def modloader_package(ecosystem: Dict[str, Any], package_id: str) -> Optional[Dict[str, Any]]:
    """Look up a modloader pack by `<namespace>-<name>` (matched case-insensitively
    on the *name* half, exactly like r2modmanPlus's MODLOADER_PACKAGES lookup)."""
    want = package_id.lower()
    for entry in ecosystem.get("modloaderPackages", []):
        pid = entry.get("packageId", "")
        if pid.lower() == want:
            return entry
        # Fall back to a name-half match, as upstream does.
        name_half = pid.split("-", 1)[1] if "-" in pid else pid
        if name_half.lower() == want:
            return entry
    return None


def steam_appid(instance: Dict[str, Any]) -> Optional[str]:
    """The Steam appid for an r2modman instance (first `steam` distribution)."""
    for dist in instance.get("distributions") or []:
        if dist.get("platform") == "steam" and dist.get("identifier"):
            return str(dist["identifier"])
    return None


def select_instance(
    game: Dict[str, Any], instance: Any = None
) -> Tuple[int, Dict[str, Any]]:
    """Pick one r2modman instance. `instance` may be None (first), an int index,
    or "game"/"server"."""
    entries = game.get("r2modman")
    if not entries:
        raise ThunderstoreError(
            f"game {game.get('label')!r} has no r2modman entry — Thunderstore "
            f"hosts it website-only, so there is no supported install layout."
        )
    if instance in (None, "", 0, "0"):
        return 0, entries[0]
    if isinstance(instance, int):
        if instance >= len(entries):
            raise ThunderstoreError(
                f"instance index {instance} out of range (game has {len(entries)})"
            )
        return instance, entries[instance]
    matches = [i for i, e in enumerate(entries) if e.get("gameInstanceType") == instance]
    if not matches:
        raise ThunderstoreError(
            f"no {instance!r} instance for {game.get('label')!r}; "
            f"available: {[e.get('gameInstanceType') for e in entries]}"
        )
    return matches[0], entries[matches[0]]


def autolist_packages(ecosystem: Dict[str, Any], slug: str) -> List[str]:
    raw = community_entry(ecosystem, slug).get("autolistPackageIds") or []
    bad = [p for p in raw if p not in LEGAL_AUTOLIST_PACKAGES]
    if bad:
        raise ThunderstoreError(
            f"community {slug!r} declares illegal autolist packages {bad}; "
            f"legal values are {sorted(LEGAL_AUTOLIST_PACKAGES)}"
        )
    return list(raw)


def describe_game(ecosystem: Dict[str, Any], slug: str) -> Dict[str, Any]:
    """A flattened, human/model-friendly view of one game — what the Nix module
    actually needs to discover an install dir and route mod files."""
    game = game_entry(ecosystem, slug)
    idx, instance = select_instance(game)
    loader = instance.get("packageLoader", "none")
    return {
        "label": game["label"],
        "uuid": game["uuid"],
        "displayName": game.get("meta", {}).get("displayName", slug),
        "community": slug,
        "instanceIndex": idx,
        "instanceType": instance.get("gameInstanceType"),
        "steamAppId": steam_appid(instance),
        "steamFolderName": instance.get("steamFolderName"),
        "dataFolderName": instance.get("dataFolderName"),
        "exeNames": instance.get("exeNames", []),
        "packageLoader": loader,
        "loaderInstallRuleDriven": loader in INSTALL_RULE_DRIVEN_LOADERS,
        "requiresDataFolder": loader in LOADERS_REQUIRING_DATA_FOLDER,
        "installRules": instance.get("installRules", []),
        "relativeFileExclusions": instance.get("relativeFileExclusions"),
        "internalFolderName": instance.get("internalFolderName"),
        "packageIndex": instance.get("packageIndex"),
        "distributions": instance.get("distributions") or game.get("distributions") or [],
        "autolistPackageIds": autolist_packages(ecosystem, slug),
        "instanceCount": len(game.get("r2modman") or []),
        "listed": community_entry(ecosystem, slug).get("listed"),
    }


# --------------------------------------------------------------------------- #
# Community package listing (chunked, content-addressed)
# --------------------------------------------------------------------------- #


def fetch_listing(community: str, refresh: bool = False) -> Dict[str, Dict[str, Any]]:
    """Every package in a community, keyed by `namespace-name`.

    Uses /c/<community>/api/v1/package-listing-index/ (302 → a content-addressed
    gzip blob holding a list of chunk URLs), then fetches each chunk. Avoids the
    unpaginated /c/<community>/api/v1/package/ dump, which is ~330 MB for a single
    mid-size community.
    """
    index_url = COMMUNITY_LISTING_INDEX.format(community=community)
    blob = _maybe_gunzip(http_get(index_url, refresh=refresh))
    try:
        chunks = json.loads(blob)
    except json.JSONDecodeError as exc:
        raise ThunderstoreError(
            f"listing index for {community!r} was not JSON after gunzip: {exc}"
        ) from exc
    if isinstance(chunks, dict):
        # Tolerate a wrapped payload rather than assuming a bare list.
        wrapped: Any = chunks.get("chunks") or chunks.get("results") or []
        chunks = list(wrapped)
    if not isinstance(chunks, list):
        raise ThunderstoreError(f"unexpected listing-index payload for {community!r}")

    packages: Dict[str, Dict[str, Any]] = {}
    for chunk_url in chunks:
        payload = _maybe_gunzip(http_get(chunk_url, refresh=refresh))
        for pkg in json.loads(payload):
            packages[pkg["full_name"]] = pkg
    return packages


def latest_version(pkg: Dict[str, Any]) -> Optional[Dict[str, Any]]:
    versions = [v for v in pkg.get("versions", []) if v.get("is_active", True)]
    if not versions:
        return None
    # The listing is newest-first; do not trust it blindly.
    return max(versions, key=version_sort_key)


def version_sort_key(version: Dict[str, Any]) -> Tuple:
    return (version.get("date_created", ""), version.get("version_number", ""))


def find_version(pkg: Dict[str, Any], spec: Optional[str]) -> Optional[Dict[str, Any]]:
    """Resolve a version spec to a concrete version record.

    `spec` may be None/"*" (newest active), "1.2.3" (exact), or ">=1.2.3" (newest
    active satisfying a simple comparison).
    """
    versions = [v for v in pkg.get("versions", []) if v.get("is_active", True)]
    if not versions:
        return None
    if spec in (None, "", "*", "latest"):
        return max(versions, key=version_sort_key)
    if spec.startswith(">="):
        floor = spec[2:]
        ok = [v for v in versions if compare_versions(v.get("version_number", ""), floor) >= 0]
        return max(ok, key=version_sort_key) if ok else None
    for v in versions:
        if v.get("version_number") == spec:
            return v
    return None


_VERSION_PART = re.compile(r"(\d+)")


def compare_versions(a: str, b: str) -> int:
    """Best-effort semver-ish comparison (numeric runs, then lexical)."""
    def parts(v: str):
        out = []
        for chunk in re.split(r"[.\-+]", v):
            m = _VERSION_PART.search(chunk)
            out.append((0, int(m.group(1)), "") if m else (-1, 0, chunk))
        return out

    pa, pb = parts(a), parts(b)
    for x, y in zip(pa, pb):
        if x != y:
            return -1 if x < y else 1
    if len(pa) == len(pb):
        return 0
    return -1 if len(pa) < len(pb) else 1


def split_dependency(dep: str, packages: Dict[str, Dict[str, Any]]) -> Optional[Tuple[str, Dict[str, Any]]]:
    """Resolve a `<ns>-<name>-<version>` dependency string to (full_name, version).

    Names may contain `-`/`_`, so we cannot split. Instead: for every candidate
    package name in the listing, check whether `dep` starts with
    `<full_name>-` and, if so, try to find that exact version.
    """
    best: Optional[Tuple[str, Dict[str, Any]]] = None
    for full_name in packages:
        prefix = f"{full_name}-"
        if not dep.startswith(prefix):
            continue
        version_spec = dep[len(prefix) :]
        version = find_version(packages[full_name], version_spec)
        if version is not None:
            return full_name, version
        best = best or (full_name, {})
    return best


def namespace_of(full_name: str, name: str) -> str:
    """`<namespace>-<name>` → namespace, for records that omit it."""
    suffix = f"-{name}"
    if name and full_name.endswith(suffix):
        return full_name[: -len(suffix)]
    return full_name.split("-", 1)[0] if "-" in full_name else full_name


def download_url(namespace: str, name: str, version: str) -> str:
    return PACKAGE_DOWNLOAD_URL.format(namespace=namespace, name=name, version=version)


def sha256_sri(data: bytes) -> str:
    """Nix SRI hash form (`sha256-<base64>`), matching the music playlist pins."""
    return "sha256-" + base64.b64encode(hashlib.sha256(data).digest()).decode()


# --------------------------------------------------------------------------- #
# Resolution
# --------------------------------------------------------------------------- #


def resolve_pack(
    community: str,
    declared: Dict[str, str],
    include_loader: Optional[str] = None,
    skip: Iterable[str] = (),
    refresh: bool = False,
) -> Dict[str, Any]:
    """Resolve declared mods + transitive dependencies into a flat pin set.

    `declared` maps `<namespace>-<name>` → version spec (exact, or None/"*" for
    newest). Returns {`<ns>-<name>-<version>`: {namespace, name, version, url,
    dependencies, isLoader, requestedAs}}. Dependencies are walked
    transitively; a dependency that cannot be resolved is reported by omission
    and listed in `unresolved` on the caller's side via the return of
    resolve_pack_with_report.

    `skip` holds full names to exclude (e.g. mods the user marked in pack.json's
    `exclude`, or a dependency we deliberately do not manage).
    """
    listing = fetch_listing(community, refresh=refresh)
    skip_set = set(skip)
    pins: Dict[str, Dict[str, Any]] = {}
    unresolved: List[str] = []
    loader_dep_skipped: List[str] = []
    queue: List[Tuple[str, Optional[str], bool, str]] = []

    loader_pkg_name = include_loader
    if include_loader:
        queue.append((include_loader, None, True, include_loader))

    for full_name, spec in declared.items():
        queue.append((full_name, spec or None, False, full_name))

    seen: set = set()
    while queue:
        full_name, spec, is_loader, requested_as = queue.pop(0)
        pkg = listing.get(full_name)
        if pkg is None:
            unresolved.append(f"{full_name} (not listed in community {community!r})")
            continue
        version = find_version(pkg, spec)
        if version is None:
            unresolved.append(f"{full_name}{'@' + spec if spec else ''} (no matching version)")
            continue
        vnum = version["version_number"]
        key = f"{full_name}-{vnum}"
        if key in pins or key in seen:
            continue
        seen.add(key)
        if full_name in skip_set:
            continue
        pins[key] = {
            "id": key,
            # A listing *version* record carries no `namespace`; the parent
            # package does, under `owner`.
            "namespace": pkg.get("owner") or namespace_of(full_name, version.get("name", "")),
            "name": version.get("name") or pkg.get("name"),
            "version": vnum,
            "url": version["download_url"]
            or download_url(pkg.get("owner", ""), version.get("name", ""), vnum),
            "dependencies": list(version.get("dependencies") or []),
            "fileSize": version.get("file_size"),
            "description": version.get("description", ""),
            "isLoader": is_loader,
            "requestedAs": requested_as,
        }
        for dep in version.get("dependencies") or []:
            resolved = split_dependency(dep, listing)
            if resolved is None:
                unresolved.append(f"{key} -> dependency {dep} (unresolvable)")
                continue
            dep_name, dep_version = resolved
            if not dep_version:
                unresolved.append(f"{key} -> dependency {dep} (version not found)")
                continue
            dep_key = f"{dep_name}-{dep_version['version_number']}"
            if dep_key in seen or dep_key in skip_set:
                continue
            if loader_pkg_name and dep_name == loader_pkg_name:
                # Every mod depends on *some* version of the loader pack; we pin
                # exactly one ourselves, so the dependency version is dropped
                # rather than installed alongside ours.
                seen.add(dep_key)
                loader_dep_skipped.append(dep_key)
                continue
            queue.append((dep_name, dep_version["version_number"], False, dep_key))

    return {
        "pins": pins,
        "unresolved": unresolved,
        "loaderDepVersionsSkipped": loader_dep_skipped,
    }


# --------------------------------------------------------------------------- #
# CLI: dump the model for one game (used by the `thunderstore-game-info` app)
# --------------------------------------------------------------------------- #


def main(argv: List[str]) -> int:
    import argparse

    ap = argparse.ArgumentParser(
        prog="thunderstore-game-info",
        description="Inspect the Thunderstore ecosystem model for a game.",
    )
    ap.add_argument("game", nargs="?", help="ecosystem slug, e.g. lethal-company")
    ap.add_argument("--instance", default=None, help="instance index, or 'game'/'server'")
    ap.add_argument("--json", action="store_true", help="emit raw JSON")
    ap.add_argument("--list", action="store_true", help="list every known game slug")
    ap.add_argument("--loaders", action="store_true", help="list every loader + platform enum")
    ap.add_argument("--refresh", action="store_true", help="bypass the HTTP cache")
    args = ap.parse_args(argv)

    if args.loaders:
        print("loaders:", ", ".join(sorted(ALL_LOADERS)))
        print("platforms:", ", ".join(sorted(ALL_PLATFORMS)))
        print("install-rule-driven:", ", ".join(sorted(INSTALL_RULE_DRIVEN_LOADERS)))
        print("legal autolist packages:", ", ".join(sorted(LEGAL_AUTOLIST_PACKAGES)))
        return 0

    eco = fetch_ecosystem(refresh=args.refresh)

    if args.list:
        rows = []
        for slug, game in eco["games"].items():
            rows.append((slug, game.get("meta", {}).get("displayName", slug)))
        for slug, name in sorted(rows):
            print(f"{slug:34s} {name}")
        print(f"\n{len(rows)} games, {len(eco.get('communities', {}))} communities")
        return 0

    if not args.game:
        ap.error("a game slug is required (or use --list / --loaders)")

    info = describe_game(eco, args.game)
    if args.instance not in (None, ""):
        idx, instance = select_instance(game_entry(eco, args.game), args.instance)
        eco2 = dict(eco)
        game = dict(game_entry(eco, args.game))
        game["r2modman"] = [instance]
        eco2["games"] = dict(eco["games"])
        eco2["games"][args.game] = game
        info = describe_game(eco2, args.game)

    if args.json:
        print(json.dumps(info, indent=2, sort_keys=True))
        return 0

    def row(label: str, value: Any) -> None:
        print(f"{label:26s} {value}")

    row("game", f"{info['displayName']}  ({info['label']}, uuid {info['uuid']})")
    row("community", info["community"])
    row("steam appid", info["steamAppId"] or "(none)")
    row("steamFolderName", info["steamFolderName"])
    row("dataFolderName", repr(info["dataFolderName"]))
    row("exeNames", ", ".join(info["exeNames"]) or "(none)")
    row("packageLoader", f"{info['packageLoader']}  (installRules-driven: {info['loaderInstallRuleDriven']})")
    row("autolist packages", ", ".join(info["autolistPackageIds"]) or "(none)")
    row("distributions", ", ".join(f"{d['platform']}:{d.get('identifier')}" for d in info["distributions"]) or "(none)")
    row("instances", f"{info['instanceCount']} (using #{info['instanceIndex']} = {info['instanceType']})")
    row("packageIndex", info["packageIndex"])
    print("\ninstall rules:")
    for rule in info["installRules"]:
        exts = ", ".join(rule.get("defaultFileExtensions") or []) or "*"
        flags = []
        if rule.get("isDefaultLocation"):
            flags.append("default")
        if rule.get("subRoutes"):
            flags.append(f"{len(rule['subRoutes'])} subRoutes")
        print(f"  {rule['route']:28s} tracking={rule['trackingMethod']:18s} exts={exts:12s} {' '.join(flags)}")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv[1:]))
    except ThunderstoreError as exc:
        print(f"thunderstore: {exc}", file=sys.stderr)
        sys.exit(1)