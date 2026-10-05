#!/usr/bin/env python3
"""
route.py — ThunderStore mod router (runs inside the Nix build, no network).

Takes a routing spec (JSON, rendered by lib/pack.nix from pack.json + game.json
+ lib/loaders.nix) and turns the extracted ThunderStore package zips into a
routed overlay plus an install plan. The overlay is what lib/install.sh copies
into the discovered Steam game directory.

    route.py <spec.json>

Spec shape (see lib/pack.nix for the producer):

    {
      "loader": "bepinex",
      "loaders": { ...lib/loaders.nix toJson... },
      "installRules": [ ...the game's r2modman[].installRules... ],
      "relativeFileExclusions": null,
      "profileDir": "<out>/profile",
      "planOut": "<out>/install-plan.json",
      "entries": [
        { "kind": "loader", "id": "BepInEx-BepInExPack-5.4.2305",
          "modName": "BepInExPack", "srcDir": "<build>/zips/loader-0",
          "rootFolder": "BepInExPack" },
        { "kind": "mod", "id": "x753-Mimics-2.7.4", "modName": "Mimics",
          "srcDir": "<build>/zips/mod-1", "rootFolder": "",
          "dependencies": ["BepInEx-BepInExPack-5.4.2100"] }
      ]
    }

Output layout — one subdirectory per destination name, so the install script
never has to know a loader's path convention:

    <profileDir>/gameRoot/BepInEx/plugins/Mimics/Mimics.dll
    <profileDir>/dataBinaries/ue4ss.dll          # shimloader
    <profileDir>/releaseDir/version.dll          # rivet

Destinations come from lib/loaders.nix (`gameRoot` | `dataBinaries` |
`releaseDir`); lib/install.sh maps each name to a concrete path under the
discovered game root.

Routing semantics implemented here mirror r2modmanPlus's InstallRulePluginInstaller
and the hardcoded plugin installers, as documented in lib/loaders.nix:

  subdir             -> <route>/<ModName>/<basename>            (contents flattened)
                         a top-level `override/` dir keeps its nesting
  subdir-no-flatten  -> <route>/<ModName>/<full relative path>
  state              -> <route>/<relative path>                  (verbatim, tracked)
  package-zip        -> <route>/<ModName>.ts.zip                 (whole mod re-zipped)
  none               -> <route>/<relative path>                  (verbatim, untracked)

Rule selection per file: the rule with the longest matching
`defaultFileExtensions` entry wins (so `.plugin.dll` beats `.dll`), otherwise the
rule flagged `isDefaultLocation`. A top-level directory in the zip whose name
equals a route's last segment is an "override folder": its contents land at the
route root, keeping nesting.
"""

from __future__ import annotations

import fnmatch
import hashlib
import json
import os
import shutil
import sys
import zipfile
from typing import Any, Dict, List, Optional, Tuple

# Fixed timestamp for re-zipped mods so `package-zip` output is reproducible.
ZIP_EPOCH = (1980, 1, 1, 0, 0, 0)


class RouteError(RuntimeError):
    pass


# --------------------------------------------------------------------------- #
# helpers
# --------------------------------------------------------------------------- #


def walk_files(root: str) -> List[str]:
    """Every regular file under `root`, as paths relative to it, sorted."""
    out: List[str] = []
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames.sort()
        for name in sorted(filenames):
            full = os.path.join(dirpath, name)
            if os.path.islink(full):
                continue  # zips carry few useful symlinks; never follow them
            out.append(os.path.relpath(full, root))
    return sorted(out)


def sha256_file(path: str) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def sha256_sri(digest_hex: str) -> str:
    import base64

    return "sha256-" + base64.b64encode(bytes.fromhex(digest_hex)).decode()


def last_segment(route: str) -> str:
    return route.rstrip("/").split("/")[-1]


def matches_extension(rel_path: str, extensions: List[str]) -> Optional[str]:
    """Longest extension in `extensions` that `rel_path` ends with (case-insensitive)."""
    name = os.path.basename(rel_path).lower()
    best: Optional[str] = None
    for ext in extensions or []:
        e = ext.lower()
        if name.endswith(e) and (best is None or len(e) > len(best)):
            best = e
    return best


def expand_subroutes(rules: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    """Flatten `subRoutes` into the rule list (upstream recurses into them)."""
    out: List[Dict[str, Any]] = []
    for rule in rules or []:
        out.append(rule)
        if rule.get("subRoutes"):
            out.extend(expand_subroutes(rule["subRoutes"]))
    return out


def pick_rule(
    rules: List[Dict[str, Any]], rel_path: str
) -> Optional[Dict[str, Any]]:
    """Choose the install rule for one file: longest matching extension, else the
    default location."""
    if not rules:
        return None
    best: Optional[Tuple[int, Dict[str, Any]]] = None
    for rule in rules:
        ext = matches_extension(rel_path, rule.get("defaultFileExtensions") or [])
        if ext is None:
            continue
        if best is None or len(ext) > best[0]:
            best = (len(ext), rule)
    if best is not None:
        return best[1]
    for rule in rules:
        if rule.get("isDefaultLocation"):
            return rule
    return None


# --------------------------------------------------------------------------- #
# the writer: records every file it places, and refuses conflicts
# --------------------------------------------------------------------------- #


class Writer:
    def __init__(self, profile_dir: str, dest: str, allow_conflicts: bool) -> None:
        self.profile_dir = profile_dir
        self.dest = dest
        self.root = os.path.join(profile_dir, dest)
        self.allow_conflicts = allow_conflicts
        self.files: Dict[str, Dict[str, Any]] = {}
        self.dirs: set = set()
        self.conflicts: List[Dict[str, str]] = []

    def mkdirs(self, rel_dirs: List[str]) -> None:
        for rel in rel_dirs:
            self.dirs.add(os.path.normpath(rel))
            os.makedirs(os.path.join(self.root, rel), exist_ok=True)

    def put(self, src: str, rel_dest: str, source_id: str) -> None:
        rel_dest = os.path.normpath(rel_dest)
        if rel_dest in (".", "") or rel_dest.startswith(".."):
            raise RouteError(f"{source_id}: refusing to write outside the profile: {rel_dest}")
        target = os.path.join(self.root, rel_dest)
        if rel_dest in self.files:
            previous = self.files[rel_dest]["source"]
            same = sha256_file(src) == self.files[rel_dest]["sha256"]
            self.conflicts.append(
                {
                    "path": rel_dest,
                    "dest": self.dest,
                    "existing_source": previous,
                    "new_source": source_id,
                    "identical": same,
                }
            )
            if not self.allow_conflicts:
                raise RouteError(
                    f"install conflict at {self.dest}/{rel_dest}: {previous} and "
                    f"{source_id} both provide this file. Drop one of them, or set "
                    f"\"allowConflicts\": true in pack.json if the overwrite is intended."
                )
            if same:
                return  # identical bytes: nothing to do
        os.makedirs(os.path.dirname(target), exist_ok=True)
        shutil.copy2(src, target)
        self.dirs.add(os.path.dirname(rel_dest))
        digest = sha256_file(target)
        self.files[rel_dest] = {
            "dest": self.dest,
            "path": rel_dest,
            "source": source_id,
            "sha256": sha256_sri(digest),
            "sha256Hex": digest,
            "size": os.path.getsize(target),
            # `chmod`-ready, no 0o prefix (python's oct() would emit "0o644").
            "mode": format(os.stat(target).st_mode & 0o7777, "04o"),
        }


# --------------------------------------------------------------------------- #
# loader payload
# --------------------------------------------------------------------------- #


def strip_root_folder(src_dir: str, root_folder: str, source_id: str) -> str:
    """Loader packs nest their payload in a `rootFolder` (from the ecosystem's
    modloaderPackages registry). `""` means the zip root."""
    if not root_folder:
        return src_dir
    candidate = os.path.join(src_dir, root_folder)
    if os.path.isdir(candidate):
        return candidate
    raise RouteError(
        f"{source_id}: loader pack has no rootFolder {root_folder!r} (looked in {src_dir})"
    )


def route_loader_entry(
    spec: Dict[str, Any], entry: Dict[str, Any], writer_root: Dict[str, Any]
) -> List[Dict[str, Any]]:
    loader_model = spec["loaders"]["byLoader"][spec["loader"]]
    payload = loader_model.get("payload") or {}
    source_id = entry["id"]
    src = strip_root_folder(entry["srcDir"], entry.get("rootFolder") or "", source_id)

    exclude = {e.lower() for e in (payload.get("exclude") or [])}
    copies = payload.get("copies") or []
    primary_dest = payload.get("dest") or loader_model["payloadDest"]

    for rel_dir in payload.get("mkdirs") or []:
        writer_root[primary_dest].mkdirs([rel_dir])

    files = walk_files(src)
    if not copies:
        raise RouteError(f"{source_id}: loader payload table is empty — refusing to guess")

    for rel in files:
        if rel.split("/")[0].lower() in exclude:
            continue
        placed = False
        for rule in copies:
            pattern = rule["from"]
            if pattern == "*" or fnmatch.fnmatch(rel, pattern) or fnmatch.fnmatch(
                rel, pattern.rstrip("/") + "/*"
            ):
                tail = rel if pattern == "*" else rel
                dest_rel = os.path.normpath(os.path.join(rule["to"], tail))
                writer_root[primary_dest].put(
                    os.path.join(src, rel), dest_rel, source_id
                )
                placed = True
                break
        if not placed and any(c["from"] != "*" for c in copies):
            # A non-`*` payload table means "only these paths are the loader".
            continue

    for extra in payload.get("copiesExtraDest") or loader_model.get("payloadExtraDest") or []:
        dest_name = extra.get("dest", "gameRoot")
        pattern = extra["from"]
        for rel in files:
            if fnmatch.fnmatch(rel, pattern) or rel == pattern:
                writer_root[dest_name].put(
                    os.path.join(src, rel), extra["to"], source_id
                )

    return [
        {"id": source_id, "files": len(writer_root[primary_dest].files)},
    ]


# --------------------------------------------------------------------------- #
# mods
# --------------------------------------------------------------------------- #


def route_mod_entry(
    spec: Dict[str, Any],
    entry: Dict[str, Any],
    writers: Dict[str, Writer],
    notes: List[str],
) -> Dict[str, Any]:
    loader = spec["loader"]
    loader_model = spec["loaders"]["byLoader"][loader]
    mod_name = entry["modName"]
    source_id = entry["id"]
    src = strip_root_folder(entry["srcDir"], entry.get("rootFolder") or "", source_id)

    if loader_model["family"] == "installRules":
        rules = expand_subroutes(spec.get("installRules") or [])
    else:
        rules = expand_subroutes(loader_model.get("mods") or [])
    if not rules:
        raise RouteError(
            f"{source_id}: loader {loader!r} has neither installRules nor hardcoded "
            f"mod routes — cannot place this mod. Report it; the loader table in "
            f"modules/home/thunderstore/lib/loaders.nix needs a `mods` entry."
        )

    route_basenames = {last_segment(r["route"]): r for r in rules}
    exclusions = {e.lower() for e in (spec.get("relativeFileExclusions") or [])}

    files = walk_files(src)
    placed = 0
    skipped: List[str] = []

    for rel in files:
        head = rel.split("/")[0]
        override_rule = route_basenames.get(head) if "/" not in rel else None

        if override_rule is not None:
            # An override folder (e.g. a mod shipping its own `plugins/`) lands
            # at the route root, keeping its nesting.
            inner = rel[len(head) + 1 :]
            rule = override_rule
            prefix = override_rule["route"]
            payload_rel = inner
        else:
            rule = pick_rule(rules, rel)
            if rule is None:
                skipped.append(rel)
                continue
            prefix = rule["route"]
            payload_rel = rel

        tracking = rule.get("trackingMethod", loader_model.get("modTracking", "subdir"))

        if tracking == "state" and payload_rel.lower() in exclusions:
            skipped.append(rel)
            continue

        if tracking == "subdir":
            if payload_rel.startswith("override/"):
                dest_rel = os.path.join(prefix, mod_name, payload_rel)
            else:
                dest_rel = os.path.join(prefix, mod_name, os.path.basename(payload_rel))
        elif tracking == "subdir-no-flatten":
            dest_rel = os.path.join(prefix, mod_name, payload_rel)
        elif tracking in ("state", "none"):
            dest_rel = os.path.join(prefix, payload_rel)
        elif tracking == "package-zip":
            continue  # handled below, once, for the whole package
        else:
            raise RouteError(
                f"{source_id}: unknown trackingMethod {tracking!r} on route {prefix!r}"
            )

        if rule.get("route") == "" or prefix == ".":
            notes.append(f"{source_id}: routed to the game root (empty route)")
        writers["gameRoot"].put(os.path.join(src, rel), dest_rel, source_id)
        placed += 1

    # package-zip loaders (godotml) want the whole mod re-zipped, not scattered.
    zip_rules = [r for r in rules if r.get("trackingMethod") == "package-zip"]
    if zip_rules:
        default_zip = next(
            (r for r in zip_rules if r.get("isDefaultLocation")), zip_rules[0]
        )
        archive_rel = os.path.join(default_zip["route"], f"{mod_name}.ts.zip")
        archive_path = os.path.join(writers["gameRoot"].root, archive_rel)
        os.makedirs(os.path.dirname(archive_path), exist_ok=True)
        with zipfile.ZipFile(archive_path, "w", zipfile.ZIP_DEFLATED) as zf:
            for rel in files:
                info = zipfile.ZipInfo(
                    os.path.join(mod_name, rel), date_time=ZIP_EPOCH
                )
                mode = os.stat(os.path.join(src, rel)).st_mode & 0o7777
                info.external_attr = (mode & 0xFFFF) << 16
                info.compress_type = zipfile.ZIP_DEFLATED
                with open(os.path.join(src, rel), "rb") as fh:
                    zf.writestr(info, fh.read())
        writer = writers["gameRoot"]
        writer.dirs.add(os.path.dirname(archive_rel))
        digest = sha256_file(archive_path)
        writer.files[archive_rel] = {
            "dest": "gameRoot",
            "path": archive_rel,
            "source": source_id,
            "sha256": sha256_sri(digest),
            "sha256Hex": digest,
            "size": os.path.getsize(archive_path),
            "mode": "0644",
        }
        placed += 1

    if skipped:
        notes.append(
            f"{source_id}: {len(skipped)} file(s) matched no install rule "
            f"(first: {skipped[0]})"
        )
    if placed == 0:
        raise RouteError(
            f"{source_id}: nothing could be placed — the zip has {len(files)} file(s) "
            f"and loader {loader!r} has rules {[r['route'] for r in rules]}"
        )

    routes = sorted(
        {
            rule["route"]
            for rule in (pick_rule(rules, f) for f in files)
            if rule is not None
        }
    )
    return {
        "id": source_id,
        "modName": mod_name,
        "files": placed,
        "routes": routes,
    }


# --------------------------------------------------------------------------- #
# main
# --------------------------------------------------------------------------- #


def main(argv: List[str]) -> int:
    if len(argv) != 1:
        print("usage: route.py <spec.json>", file=sys.stderr)
        return 2
    with open(argv[0]) as fh:
        spec = json.load(fh)

    loader = spec["loader"]
    if loader not in spec["loaders"]["byLoader"]:
        raise RouteError(
            f"loader {loader!r} is not modelled in lib/loaders.nix "
            f"(known: {sorted(spec['loaders']['byLoader'])})"
        )

    profile_dir = spec["profileDir"]
    allow_conflicts = bool(spec.get("allowConflicts"))
    os.makedirs(profile_dir, exist_ok=True)

    destinations = spec["loaders"]["destinations"]
    writers = {name: Writer(profile_dir, name, allow_conflicts) for name in destinations}

    summary: Dict[str, Any] = {"loader": loader, "loaderEntries": [], "modEntries": []}
    notes: List[str] = []

    for entry in spec["entries"]:
        if entry["kind"] == "loader":
            summary["loaderEntries"].extend(route_loader_entry(spec, entry, writers))
        elif entry["kind"] == "mod":
            summary["modEntries"].append(route_mod_entry(spec, entry, writers, notes))
        else:
            raise RouteError(f"unknown entry kind {entry['kind']!r}")

    # Mod files always land in the game root (installRules routes are relative to
    # it); the extra destinations exist for loader payloads.
    plan = {
        "pack": spec.get("pack"),
        "game": spec.get("game"),
        "loader": loader,
        "destinations": {
            name: {
                "description": spec["loaders"].get("destinationDocs", {}).get(name, name),
                "fileCount": len(w.files),
            }
            for name, w in writers.items()
        },
        "dirs": sorted({f"{name}/{d}" for name, w in writers.items() for d in w.dirs if d}),
        "files": [f for name in destinations for f in writers[name].files.values()],
        "conflicts": [c for w in writers.values() for c in w.conflicts],
        "notes": notes,
    }

    plan_out = spec["planOut"]
    if os.path.dirname(plan_out):
        os.makedirs(os.path.dirname(plan_out), exist_ok=True)
    with open(plan_out, "w") as fh:
        json.dump(plan, fh, indent=1, sort_keys=True)

    with open(spec["manifestOut"], "w") as fh:
        json.dump(summary, fh, indent=1, sort_keys=True)

    total = len(plan["files"])
    print(f"thunderstore-route: {loader}: {total} file(s) across {len(spec['entries'])} package(s)")
    for dest, info in plan["destinations"].items():
        if info["fileCount"]:
            print(f"  {dest:14s} {info['fileCount']} file(s)")
    for note in notes:
        print(f"  note: {note}")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv[1:]))
    except RouteError as exc:
        print(f"thunderstore-route: {exc}", file=sys.stderr)
        sys.exit(1)