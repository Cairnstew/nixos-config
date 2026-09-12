"""Shared infrastructure for packwiz datapack scanners.

Provides the common utilities duplicated across items.py, mobs.py, structures.py,
and the new recipes.py / loot.py tools.  Each scanner imports from here instead of
copying ~200 lines of boilerplate.

Usage:
    from datapack_common import (
        die, repo_root, mc_version, cached_jar, find_mod_jars, resolve_mod,
        dir_to_zip, paxi_dir, resolve_pack_dir, read_pack_info, fuzzy_match,
        resolve_item_ref,
    )
"""

import os
import re
import sys
import json
import shutil
import zipfile
import tempfile
import subprocess
import urllib.request


def die(msg, tool=None):
    """Print an error to stderr and exit 1.  `tool` is prepended if given."""
    prefix = f"{tool}: " if tool else ""
    sys.stderr.write(f"{prefix}{msg}\n")
    sys.exit(1)


def repo_root():
    """Git top-level from the cwd, else the script's own ancestor repo."""
    out = subprocess.run(["git", "rev-parse", "--show-toplevel"],
                         capture_output=True, text=True, cwd=os.getcwd())
    if out.returncode == 0:
        return out.stdout.strip()
    here = os.path.abspath(os.path.dirname(__file__))
    for _ in range(5):
        here = os.path.dirname(here)
    if os.path.exists(os.path.join(here, "flake.nix")):
        return here
    return os.getcwd()


def mc_version(pack_dir):
    p = os.path.join(pack_dir, "pack.toml")
    if not os.path.exists(p):
        return None
    m = re.search(r'^minecraft\s*=\s*"([^"]+)"', open(p).read(), re.M)
    return m.group(1) if m else None


def _jar_cache():
    d = os.path.join(tempfile.gettempdir(), "mc-pack-jars")
    os.makedirs(d, exist_ok=True)
    return d


def cached_jar(entry):
    """Pinned jar to a local file (cached by sha256). Returns (path, downloaded)."""
    sha = entry.get("sha256")
    if sha:
        safe = re.sub(r"[^A-Za-z0-9_.-]", "_", sha)
        local = os.path.join(_jar_cache(), safe)
        if os.path.exists(local):
            return local, False
        tmp = local + ".tmp"
        urllib.request.urlretrieve(entry["url"], tmp)
        os.replace(tmp, local)
        return local, True
    tmp = tempfile.mkdtemp(prefix="mc-jar-")
    local = os.path.join(tmp, "mod.jar")
    urllib.request.urlretrieve(entry["url"], local)
    return local, True


def find_mod_jars(pack_dir):
    """A dict of every alias -> {pw_toml, url?, sha256?} for the pack's mods."""
    mods_dir = os.path.join(pack_dir, "mods")
    out = {}
    cs = {}
    cs_path = os.path.join(pack_dir, "checksums.json")
    if os.path.exists(cs_path):
        with open(cs_path) as fh:
            cs = json.load(fh)
    if not os.path.isdir(mods_dir):
        return out
    for f in sorted(os.listdir(mods_dir)):
        if not f.endswith(".pw.toml"):
            continue
        txt = open(os.path.join(mods_dir, f)).read()
        slug = None
        m = re.search(r'^name\s*=\s*"([^"]+)"', txt, re.M)
        if m:
            slug = m.group(1).lower()
        url = None
        dm = re.search(r"^\[download\]\s*\n(.*?)(?=\n\[|\Z)", txt, re.S | re.M)
        if dm:
            um = re.search(r'^url\s*=\s*"([^"]+)"', dm.group(1), re.M)
            if um:
                url = um.group(1)
        entry = {"pw_toml": f}
        if url:
            entry["url"] = url
        if f in cs:
            entry["sha256"] = cs[f].get("sha256")
            if not url and cs[f].get("url"):
                entry["url"] = cs[f]["url"]
        fstem = f[:-8].lower()
        jarstem = None
        fm = re.search(r'^filename\s*=\s*"([^"]+)"', txt, re.M)
        if fm:
            jarstem = os.path.splitext(os.path.basename(fm.group(1)))[0].lower()
        out[slug or fstem] = entry
        if slug and slug != fstem:
            out.setdefault(fstem, entry)
        if jarstem:
            out.setdefault(jarstem, entry)
    return out


def resolve_mod(mods, target):
    tl = target.lower()
    if tl in mods:
        return tl
    matches = [k for k in mods if tl in k or k in tl]
    if len(matches) == 1:
        return matches[0]
    if len(matches) > 1:
        die(f"ambiguous '{target}' — matches {sorted(matches)}; "
            "pass a unique slug or .pw.toml filename")
    return None


def dir_to_zip(d):
    """Zip a datapack directory into a temp file for scanning."""
    tmp = tempfile.mkdtemp(prefix="mc-dp-")
    zip_path = os.path.join(tmp, "dp.zip")
    with zipfile.ZipFile(zip_path, "w") as zf:
        for root, _, files in os.walk(d):
            for f in files:
                full = os.path.join(root, f)
                rel = os.path.relpath(full, d)
                zf.write(full, rel)
    return tmp, zip_path


def paxi_dir(pack_dir):
    return os.path.join(pack_dir, "config", "paxi", "datapacks")


# ── pack resolution ───────────────────────────────────────────────────────────

def resolve_pack_dir(pack_arg):
    if os.path.isdir(pack_arg):
        return os.path.abspath(pack_arg)
    base = os.path.abspath(pack_arg)
    if os.path.isdir(base):
        return base
    cands = [
        os.path.join(repo_root(), "modules", "nixos", "minecraft-server",
                     "modpacks", pack_arg),
        os.path.join(os.getcwd(), pack_arg),
    ]
    for c in cands:
        if os.path.isdir(c):
            return c
    d = os.path.join(repo_root(), "modules", "nixos", "minecraft-server",
                     "modpacks")
    if os.path.isdir(d):
        for name in sorted(os.listdir(d)):
            if name.lower() == pack_arg.lower() and os.path.isdir(
                    os.path.join(d, name)):
                return os.path.join(d, name)
    die(f"can't find packwiz pack '{pack_arg}' "
        "(tried paths and the repo's modpacks/)")
    return None


def read_pack_info(pack_dir):
    info = {"name": os.path.basename(pack_dir.rstrip("/")), "dir": pack_dir,
            "minecraft": None, "loader": None, "loader_version": None}
    p = os.path.join(pack_dir, "pack.toml")
    if not os.path.exists(p):
        die(f"{pack_dir} is not a packwiz pack (no pack.toml)")
    txt = open(p).read()
    m = re.search(r'^minecraft\s*=\s*"([^"]+)"', txt, re.M)
    if m:
        info["minecraft"] = m.group(1)
    for loader in ("neoforge", "forge", "fabric", "quilt"):
        m = re.search(rf"^{loader}\s*=\s*\"([^\"]+)\"", txt, re.M)
        if m:
            info["loader"], info["loader_version"] = loader, m.group(1)
            break
    return info


# ── info helpers ───────────────────────────────────────────────────────────────

def fuzzy_match(target, known_ids, max_results=5):
    """Cheap fuzzy match using difflib.SequenceMatcher."""
    import difflib
    t = target.lower()
    t_short = t.split(":")[-1] if ":" in t else t
    scored = []
    for sid in known_ids:
        s = sid.lower()
        s_short = s.split(":")[-1] if ":" in s else s
        if t == s or t_short == s_short:
            return []
        ratio = difflib.SequenceMatcher(None, t_short, s_short).ratio()
        if ratio >= 0.6:
            scored.append((ratio, sid))
    scored.sort(key=lambda x: (-x[0], x[1]))
    return [sid for _, sid in scored[:max_results]]


# ── shared item helpers ───────────────────────────────────────────────────────

def resolve_item_ref(ref):
    """Normalize an item reference to namespace:path format.
    Handles: 'minecraft:diamond', 'diamond', '#minecraft:planks' (tag -> None).
    Object form: {"item": "...", "count": 1} or {"tag": "..."}."""
    if isinstance(ref, dict):
        if "tag" in ref and len(ref) == 1:
            return None
        ref = ref.get("item") or ref.get("id") or ref.get("name")
        if not ref:
            return None
    if not isinstance(ref, str):
        return None
    if ref.startswith("#"):
        return None
    if ":" not in ref:
        ref = f"minecraft:{ref}"
    return ref


# ── shared scanner loops ──────────────────────────────────────────────────────

def scan_mods(pack_dir, info, scan_fn, want_mods=None, skipped=None):
    """Generic mod-jar scan loop.

    `scan_fn(zf) -> dict` is called on each jar's zipfile and should return
    the entity data for that source (keys depend on the scanner).

    Returns (sources, dl, from_cache)."""
    mods = find_mod_jars(pack_dir)
    by_toml = {}
    for k, e in mods.items():
        by_toml.setdefault(e["pw_toml"], []).append(k)
    selected = []
    if want_mods:
        for t in want_mods:
            k = resolve_mod(mods, t)
            if k is None:
                die(f"no mod '{t}' in pack (unique mod ids: "
                    f"{', '.join(sorted(by_toml))[:400]})")
            toml = mods[k]["pw_toml"]
            if toml not in selected:
                selected.append(toml)
    else:
        selected = sorted(set(e["pw_toml"] for e in mods.values()))

    sources = []
    dl = from_cache = 0
    for toml in selected:
        entry = mods[by_toml[toml][0]]
        if not entry.get("url"):
            skipped.append(toml)
            continue
        local, was_dl = cached_jar(entry)
        if was_dl:
            dl += 1
        else:
            from_cache += 1
        with zipfile.ZipFile(local) as zf:
            extracted = scan_fn(zf)
        sources.append({
            "kind": "mod",
            "name": by_toml[toml][0],
            "jar": entry["url"].rsplit("/", 1)[-1],
            "data": extracted,
        })
    return sources, dl, from_cache


def scan_datapacks(pack_dir, scan_fn, skipped_dp=None):
    """Generic datapack scan loop (Paxi dir + pack data/)."""
    sources = []
    dp_root = paxi_dir(pack_dir)
    if os.path.isdir(dp_root):
        for name in sorted(os.listdir(dp_root)):
            p = os.path.join(dp_root, name)
            if os.path.isdir(p):
                tmp, zip_path = dir_to_zip(p)
                try:
                    with zipfile.ZipFile(zip_path) as zf:
                        extracted = scan_fn(zf)
                finally:
                    shutil.rmtree(tmp, ignore_errors=True)
                sources.append({"kind": "datapack",
                                "name": f"config/paxi/datapacks/{name}/",
                                "jar": None, "data": extracted})
            elif name.endswith(".zip"):
                try:
                    with zipfile.ZipFile(p) as zf:
                        extracted = scan_fn(zf)
                except zipfile.BadZipFile:
                    if skipped_dp is not None:
                        skipped_dp.append(f"{name}: not a valid zip")
                    continue
                sources.append({"kind": "datapack",
                                "name": f"config/paxi/datapacks/{name}",
                                "jar": None, "data": extracted})
    data_dir = os.path.join(pack_dir, "data")
    if os.path.isdir(data_dir):
        tmp, zip_path = dir_to_zip(data_dir)
        try:
            with zipfile.ZipFile(zip_path) as zf:
                extracted = scan_fn(zf)
        finally:
            shutil.rmtree(tmp, ignore_errors=True)
        sources.append({"kind": "datapack", "name": "<pack>/data/",
                        "jar": None, "data": extracted})
    return sources
