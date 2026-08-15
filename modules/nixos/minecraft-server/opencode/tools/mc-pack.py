#!/usr/bin/env python3
"""Manage internal files (configs, datapacks) in a packwiz modpack.

Usage: mc-pack.py <modpack-dir> <command> [args...]

Commands:
  config add <rel-path> [--content <text> | --from <file>] [--preserve]
      Create/overwrite config/<rel-path> in the pack, then run `packwiz refresh`
      so the file is indexed. With --preserve, also mark the index entry so a
      player's existing copy is never overwritten.
  config preserve <rel-path> [on|off]
      Set/clear `preserve = true` on the index.toml entry for config/<rel-path>.
      Preserve = install the file only if it doesn't already exist (player edits
      win). packwiz has no CLI for this — it's an index.toml-only property.
  config list [--all]
      List internal files shipped by the pack (config/, kubejs/, scripts/,
      datapacks/, defaultconfigs/) with their indexed/preserve state. Default
      shows config/ only; --all shows every internal dir.
  config diff <rel-path>
      Compare the pack's config/<rel-path> against the owning mod's stock
      default: finds the mod jar via checksums.json (downloads it), unzips its
      bundled config, and prints a unified diff.
  config show <mod> [config/<path>...] [--contents]
      Review/get the config a specific mod ships: resolve the mod to its
      PINNED jar (checksums.json — the exact jar players get), list every
      config/ file it bundles (with size and whether the pack overrides it),
      and print the contents of a chosen file (or all with --contents).
      Owning-mod mapping for overrides uses the first path segment under
      config/ as the modid.
  jar-meta <mod> [member]
      Print a member (default META-INF/neoforge.mods.toml) from a mod's PINNED
      jar — the exact bytes a build-time patch (patches/<mod>.py) must match.
      Use to write/verify patches for metadata config changes cannot control.
   structures [--mods slug1,slug2...] [--no-datapacks]
       Review every worldgen structure + structure set the pack will generate,
       from the pinned mod jars and the pack's own datapacks
       (config/paxi/datapacks/ + any <pack>/data/). Flags: --mods restricts to
       listed mods; --no-datapacks skips the datapack scan.
   controls [--options <path>] [--dataDir <dir>] [--mod <slug>]
       Review the default hotkeys/controls for the whole modpack: reads the
       effective keybindings (the pack's shipped options.txt if any, else a
       generated one from a Prism instance, else --options <path>) and resolves
       each keybind id to a label + owning mod via the pinned jars' lang files.
       Flags: --options forces a specific options.txt; --dataDir overrides the
       Prism data dir for instance auto-detection; --mod filters to one mod.
   controls-set [--key key_<id>=<code> ...] [--from <file>] [--preserve]
       Write/edit the pack's DEFAULT options.txt at the pack root (maps to the
       game root on install). --key sets/updates one keybind line each;
       --from seeds from a generated options.txt to copy non-key settings too.
  datapack add <local-zip-or-dir> [--name <name>]
      Copy a local datapack into config/paxi/datapacks/ (the Paxi loader folder),
      validate its pack.mcmeta pack_format matches the pack's Minecraft version,
      then run `packwiz refresh`.
  datapack remove <name>
      Remove config/paxi/datapacks/<name> (zip or dir), then refresh.
  inspect <mod-slug-or-name> [--jar]
      Query the Modrinth API for a mod: deps, side, loaders, downloads. With
      --jar, also downloads the latest jar and lists the config/ files it ships.

Each file-editing command runs `packwiz refresh` afterwards (via the repo's
.#packwiz app) so index.toml stays in sync — skipping it causes hash
mismatches on install. Packwiz refresh preserves `preserve` flags it finds.
"""
import os
import re
import sys
import json
import shutil
import difflib
import hashlib
import zipfile
import tempfile
import subprocess
import urllib.request

MODRINTH_API = "https://api.modrinth.com/v2"

# Minecraft version -> data pack format number. From
# https://minecraft.wiki/w/Pack_format (the folder renames land in 1.21.x).
PACK_FORMATS = {
    "1.20.5": 41, "1.20.6": 41,
    "1.21": 48, "1.21.1": 48,
    "1.21.2": 57, "1.21.3": 57,
    "1.21.4": 61,
    "1.21.5": 71, "1.21.6": 71,
}

INTERNAL_DIRS = ["config", "kubejs", "scripts", "datapacks", "defaultconfigs"]


def die(msg):
    sys.stderr.write(f"mc-pack: {msg}\n")
    sys.exit(1)


def repo_root():
    out = subprocess.run(["git", "rev-parse", "--show-toplevel"],
                         capture_output=True, text=True, cwd=os.getcwd())
    return out.stdout.strip() if out.returncode == 0 else os.getcwd()


def read_pack_toml(pack_dir):
    with open(os.path.join(pack_dir, "pack.toml")) as fh:
        return fh.read()


def mc_version(pack_dir):
    m = re.search(r'^minecraft\s*=\s*"([^"]+)"', read_pack_toml(pack_dir), re.M)
    return m.group(1) if m else None


def run_refresh(pack_dir):
    repo = repo_root()
    subprocess.run(
        ["nix", "run", f"{repo}#packwiz", "--", "refresh"],
        cwd=pack_dir, check=False, capture_output=True, text=True,
    )


_JAR_CACHE = None


def jar_cache():
    """A dir keyed by sha256 for downloaded pinned jars, so full-pack scans
    (e.g. `structures`) don't re-download every jar on each run."""
    global _JAR_CACHE
    if _JAR_CACHE is None:
        d = os.path.join(tempfile.gettempdir(), "mc-pack-jars")
        os.makedirs(d, exist_ok=True)
        _JAR_CACHE = d
    return _JAR_CACHE


def cached_jar(entry):
    """Download a pinned jar (checksums.json sha256) into the jar cache and
    return the local path. Returns (path, downloaded_bool)."""
    sha = entry.get("sha256")
    if sha:
        # checksums.json sha256 is a Nix SRI hash ("sha256-<base64>") containing
        # '/' and '+' — sanitize for use as a filename.
        safe = re.sub(r"[^A-Za-z0-9_.-]", "_", sha)
        local = os.path.join(jar_cache(), safe)
        if os.path.exists(local):
            return local, False
        tmp = local + ".tmp"
        urllib.request.urlretrieve(entry["url"], tmp)
        os.replace(tmp, local)
        return local, True
    # No checksum pinned — download to a throwaway path (CurseForge-mode mods).
    tmp = tempfile.mkdtemp(prefix="mc-jar-")
    local = os.path.join(tmp, "mod.jar")
    urllib.request.urlretrieve(entry["url"], local)
    return local, True


def find_mod_jars(pack_dir):
    """slug -> {pw_toml, filename, url, sha256} for every mod in the pack."""
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


def owning_mod(pack_dir, rel_path):
    """Best-effort: return (slug, mod_entry) for the mod that ships rel_path.
    Uses the first path segment under config/ as the mod id."""
    parts = rel_path.split("/")
    if len(parts) < 2 or parts[0] != "config":
        return None, None
    modid = parts[1].lower()
    mods = find_mod_jars(pack_dir)
    for slug in mods:
        if slug == modid:
            return slug, mods[slug]
    for slug, entry in mods.items():
        if slug.startswith(modid) or modid.startswith(slug):
            return slug, entry
    return None, None

# ── index.toml editing (preserve flag) ───────────────────────────────────────

def read_index(pack_dir):
    p = os.path.join(pack_dir, "index.toml")
    return open(p).read() if os.path.exists(p) else None


def write_index(pack_dir, text):
    with open(os.path.join(pack_dir, "index.toml"), "w") as fh:
        fh.write(text)


def index_entry(text, rel_path):
    """Return the [[files]] block text containing file = "<rel_path>", or None."""
    for block in re.split(r"(?=^\[\[files\]\])", text, flags=re.M):
        if re.search(r'^file\s*=\s*"' + re.escape(rel_path) + r'"', block, re.M):
            return block
    return None


def set_preserve(pack_dir, rel_path, on):
    text = read_index(pack_dir)
    if text is None:
        die(f"no index.toml in {pack_dir} — run packwiz init first")
    block = index_entry(text, rel_path)
    if block is None:
        die(f"'{rel_path}' is not in index.toml — run `packwiz refresh` first")
    if on and re.search(r"^preserve\s*=\s*true", block, re.M):
        return "already preserve = true"
    if not on and not re.search(r"^preserve\s*=\s*true", block, re.M):
        return "already has no preserve flag"
    # Insert/remove preserve right after the file = line within its block.
    if on:
        new_block = re.sub(
            r'(^file\s*=\s*"[^"]*"\s*\n)',
            r"\1preserve = true\n",
            block, count=1, flags=re.M,
        )
    else:
        new_block = re.sub(r"^preserve\s*=\s*true\s*\n?", "", block, flags=re.M)
    write_index(pack_dir, text.replace(block, new_block))
    return "preserve = true" if on else "preserve removed"


# ── config subcommands ───────────────────────────────────────────────────────

def cmd_config_add(pack_dir, args):
    if len(args) < 1:
        die("config add <rel-path> [--content <text> | --from <file>] [--preserve]")
    rel = args[0]
    if rel.startswith("config/"):
        rel = rel[len("config/"):]
    content = None
    preserve = False
    i = 1
    while i < len(args):
        a = args[i]
        if a == "--content" and i + 1 < len(args):
            content = args[i + 1]; i += 2
        elif a == "--from" and i + 1 < len(args):
            with open(args[i + 1]) as fh:
                content = fh.read()
            i += 2
        elif a == "--preserve":
            preserve = True; i += 1
        else:
            die(f"unknown arg {a}")
    dest = os.path.join(pack_dir, "config", rel)
    if content is None:
        die("no content given — use --content <text> or --from <file>")
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    with open(dest, "w") as fh:
        fh.write(content)
    run_refresh(pack_dir)
    idx = f"config/{rel}"
    lines = [f"wrote config/{rel} and refreshed the index"]
    if preserve:
        lines.append(set_preserve(pack_dir, idx, True))
    print("\n".join(lines))


def cmd_config_preserve(pack_dir, args):
    if len(args) < 1:
        die("config preserve <rel-path> [on|off]")
    rel = args[0]
    if rel.startswith("config/"):
        rel = rel[len("config/"):]
    on = len(args) < 2 or args[1] != "off"
    print(set_preserve(pack_dir, f"config/{rel}", on))


def cmd_config_list(pack_dir, args):
    show_all = "--all" in args
    dirs = INTERNAL_DIRS if show_all else ["config"]
    text = read_index(pack_dir) or ""
    for d in dirs:
        base = os.path.join(pack_dir, d)
        if not os.path.isdir(base):
            continue
        print(f"## {d}/")
        for root, _, files in os.walk(base):
            for f in sorted(files):
                if f.endswith(".pw.toml"):
                    continue
                rel = os.path.relpath(os.path.join(root, f), pack_dir).replace(os.sep, "/")
                block = index_entry(text, rel)
                if block is None:
                    status = "NOT INDEXED (run refresh)"
                elif re.search(r"^preserve\s*=\s*true", block, re.M):
                    status = "preserve"
                else:
                    status = "overwrite"
                print(f"  {rel:<40} {status}")


def cmd_config_diff(pack_dir, args):
    if len(args) < 1:
        die("config diff <rel-path>")
    rel = args[0]
    if rel.startswith("config/"):
        rel = rel[len("config/"):]
    local = os.path.join(pack_dir, "config", rel)
    if not os.path.exists(local):
        die(f"config/{rel} not in the pack")
    slug, entry = owning_mod(pack_dir, f"config/{rel}")
    if not entry or "url" not in entry:
        die(f"couldn't find an owning mod for config/{rel} (checked mods/*.pw.toml + checksums.json)")
    jar_url = entry["url"]
    tmp = tempfile.mkdtemp(prefix="mc-diff-")
    jar = os.path.join(tmp, "mod.jar")
    try:
        print(f"downloading {slug} ({jar_url.split('/')[-1][:60]}…)")
        urllib.request.urlretrieve(jar_url, jar)
        with zipfile.ZipFile(jar) as zf:
            # The bundled config may be config/<modid>/... or config/<file>.
            candidates = [f"config/{rel}"]
            parts = rel.split("/")
            if len(parts) > 1:
                candidates.append(f"config/{parts[0]}/{parts[1]}")
            cand = next((c for c in candidates if c in zf.namelist()), None)
            if cand is None:
                print(f"no bundled config found in the jar (looked in: {', '.join(candidates)})")
                return
            stock = zf.read(cand).decode("utf-8", errors="replace").splitlines()
        local_lines = open(local).read().splitlines()
        diff = difflib.unified_diff(
            stock, local_lines, fromfile=f"{slug} stock ({cand})", tofile=f"pack ({rel})"
        )
        out = "\n".join(diff)
        print(out if out.strip() else "(identical to the mod's stock config)")
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


def resolve_mod(mods, target):
    """Return the unique key for a mod name/slug/pw-toml-filename, or None."""
    tl = target.lower()
    if tl in mods:
        return tl
    matches = [k for k in mods if tl in k or k in tl]
    if len(matches) == 1:
        return matches[0]
    if len(matches) > 1:
        die(f"ambiguous '{target}' — matches {', '.join(sorted(matches))}; pass a unique slug or .pw.toml filename")
    return None


def no_mod_error(pack_dir, target):
    stems = sorted(f[:-8] for f in os.listdir(os.path.join(pack_dir, "mods")) if f.endswith(".pw.toml"))
    shown = ", ".join(stems[:25]) + ("…" if len(stems) > 25 else "")
    return f"no mod '{target}' in pack. Unique mod ids: {shown}"


def override_status(pack_dir, jar_rel_path, zf):
    """Short status for a jar config path vs the pack's config/ dir:
    no pack override | identical override | differing override."""
    rel = jar_rel_path[len("config/"):] if jar_rel_path.startswith("config/") else jar_rel_path
    local = os.path.join(pack_dir, "config", rel)
    if not os.path.exists(local):
        return " (no pack override)"
    try:
        stock = zf.read(jar_rel_path).decode("utf-8", errors="replace")
    except KeyError:
        return " (pack has override; not in this jar)"
    local_txt = open(local, encoding="utf-8", errors="replace").read()
    if stock == local_txt:
        return " (pack override: identical)"
    return " (pack override: DIFFERS — review with packwiz-config-diff)"


def cmd_config_show(pack_dir, args):
    if len(args) < 1:
        die("config show <mod> [config/<path>...] [--contents]")
    target = args[0]
    rest = args[1:]
    show_contents = "--contents" in rest
    paths = [a for a in rest if not a.startswith("--")]
    mods = find_mod_jars(pack_dir)
    key = resolve_mod(mods, target)
    if key is None:
        die(no_mod_error(pack_dir, target))
    entry = mods[key]
    if not entry.get("url"):
        die(f"'{key}' has no download URL (CurseForge-mode mod?) — convert it first; see the mc-modpack skill")
    print(f"{key} → {entry['pw_toml']}  ({entry['url'].rsplit('/', 1)[-1]})")
    tmp = tempfile.mkdtemp(prefix="mc-show-")
    jar = os.path.join(tmp, "mod.jar")
    try:
        urllib.request.urlretrieve(entry["url"], jar)
        with zipfile.ZipFile(jar) as zf:
            cfg = sorted(n for n in zf.namelist() if n.startswith("config/") and not n.endswith("/"))
            if not cfg:
                print("  ships no config/ files")
                return
            if not paths and not show_contents:
                print(f"  ships {len(cfg)} config file(s):")
                for c in cfg:
                    info = zf.getinfo(c)
                    print(f"    {c}  ({info.file_size:,} B){override_status(pack_dir, c, zf)}")
                return
            sel = [f"config/{p}" if not p.startswith("config/") else p for p in (paths or cfg)]
            for c in sel:
                if c not in zf.namelist():
                    print(f"  !! no such file in jar: {c}")
                    continue
                info = zf.getinfo(c)
                print(f"── {c} ({info.file_size:,} B){override_status(pack_dir, c, zf)}")
                try:
                    lines = zf.read(c).decode("utf-8", errors="replace").splitlines()
                except Exception as e:  # noqa: BLE001
                    lines = [f"(unreadable: {e})"]
                print("\n".join(lines[:400]))
                if len(lines) > 400:
                    print(f"  … ({len(lines) - 400} more lines; total {len(lines)})")
                print()
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


def cmd_jar_meta(pack_dir, args):
    """Print a member (default META-INF/neoforge.mods.toml) from a mod's PINNED
    jar — the exact bytes a build-time patch (patches/<mod>.py) must match."""
    if len(args) < 1:
        die("jar-meta <mod> [member]")
    target = args[0]
    member = args[1] if len(args) > 1 else "META-INF/neoforge.mods.toml"
    mods = find_mod_jars(pack_dir)
    key = resolve_mod(mods, target)
    if key is None:
        die(no_mod_error(pack_dir, target))
    entry = mods[key]
    if not entry.get("url"):
        die(f"'{key}' has no download URL (CurseForge-mode mod?) — convert it first; see the mc-modpack skill")
    print(f"{key} → {entry['pw_toml']}  ({entry['url'].rsplit('/', 1)[-1]})")
    tmp = tempfile.mkdtemp(prefix="mc-jarmeta-")
    jar = os.path.join(tmp, "mod.jar")
    try:
        urllib.request.urlretrieve(entry["url"], jar)
        with zipfile.ZipFile(jar) as zf:
            if member in zf.namelist():
                lines = zf.read(member).decode("utf-8", errors="replace").splitlines()
                print(f"── {member} ({len(lines)} lines)")
                print("\n".join(lines[:500]))
                if len(lines) > 500:
                    print(f"  … ({len(lines) - 500} more lines)")
                return
            tomls = sorted(n for n in zf.namelist() if n.startswith("META-INF/") and n.endswith(".toml"))
            print(f"  !! '{member}' not in the jar. META-INF/*.toml files: {', '.join(tomls) or '(none)'}")
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


# ── structures subcommand ────────────────────────────────────────────────────
# Reviews every worldgen structure/structure-set a modpack will add: from the
# pack's pinned mod jars (checksums.json — exactly what players get) and from
# the pack's own datapacks (config/paxi/datapacks/ + any pack-level data/).

VANILLA_STRUCTURE_SETS = {
    "minecraft:ancient_cities", "minecraft:bastion_remnants", "minecraft:buried_treasures",
    "minecraft:desert_pyramids", "minecraft:end_cities", "minecraft:igloos",
    "minecraft:jungle_temples", "minecraft:mansion", "minecraft:mansions",
    "minecraft:mineshafts", "minecraft:monuments", "minecraft:nether_complexes",
    "minecraft:nether_fossils", "minecraft:ocean_monuments", "minecraft:ocean_ruins",
    "minecraft:pillager_outposts", "minecraft:ruined_portals", "minecraft:shipwrecks",
    "minecraft:strongholds", "minecraft:swamp_huts", "minecraft:trail_ruins",
    "minecraft:trial_chambers", "minecraft:villages", "minecraft:woodland_mansions",
}


def scan_worldgen(zf):
    """Scan a jar/datapack zip for worldgen structure files.
    Returns (structures, sets):
      structures = { "<ns>:<name>": {"type": ..., "biomes": ...} }
      sets       = { "<ns>:<setname>": [structure ids...] }"""
    structures, sets = {}, {}
    for n in zf.namelist():
        m = re.match(r"^data/([^/]+)/worldgen/structure/(.+)\.json$", n)
        if m:
            ns, name = m.group(1), m.group(2)
            try:
                data = json.loads(zf.read(n))
            except Exception:  # noqa: BLE001
                data = {}
            structures[f"{ns}:{name}"] = {
                "type": data.get("type", "?"), "biomes": data.get("biomes", ""),
            }
            continue
        m = re.match(r"^data/([^/]+)/worldgen/structure_set/(.+)\.json$", n)
        if m:
            ns, name = m.group(1), m.group(2)
            try:
                data = json.loads(zf.read(n))
            except Exception:  # noqa: BLE001
                data = {}
            sets[f"{ns}:{name}"] = [s.get("structure", "?") for s in data.get("structures", [])]
            continue
    return structures, sets


def _report_source(label, structures, sets, indent="  "):
    print(f"{indent}## {label}")
    for sid in sorted(structures):
        s = structures[sid]
        extra = ""
        if sid.startswith("minecraft:"):
            extra = "  [OVERLAPS VANILLA — this replaces/overrides the vanilla one]"
        print(f"{indent}  structure  {sid}  (type={s['type']}, biomes={s['biomes'] or '?'}){extra}")
    for sid in sorted(sets):
        members = sets[sid]
        extra = ""
        if sid in VANILLA_STRUCTURE_SETS:
            extra = "  [VANILLA SET NAME — a datapack set here would override it]"
        print(f"{indent}  set        {sid}  ->  {', '.join(members) or '(empty)'}{extra}")


def cmd_structures(pack_dir, args):
    """structures [--mods slug1,slug2...] [--no-datapacks]
    Review every worldgen structure + structure set the pack will generate:
    from the pinned mod jars and the pack's own datapacks."""
    want_mods = None
    scan_dp = True
    i = 0
    while i < len(args):
        a = args[i]
        if a == "--mods" and i + 1 < len(args):
            want_mods = [s.strip().lower() for s in args[i + 1].split(",") if s.strip()]
            i += 2
        elif a == "--no-datapacks":
            scan_dp = False; i += 1
        else:
            die(f"unknown arg {a}")
    mods = find_mod_jars(pack_dir)
    keys = sorted(set(mods.values() and (mods[k]["pw_toml"] for k in mods)))
    by_toml = {}
    for k, e in mods.items():
        by_toml.setdefault(e["pw_toml"], []).append(k)
    selected = []
    if want_mods:
        for t in want_mods:
            k = resolve_mod(mods, t)
            if k is None:
                die(no_mod_error(pack_dir, t))
            toml = mods[k]["pw_toml"]
            if toml not in selected:
                selected.append(toml)
    else:
        selected = sorted(set(e["pw_toml"] for e in mods.values()))

    all_structures, all_sets = {}, {}
    dl = 0
    for toml in selected:
        entry = mods[by_toml[toml][0]]
        if not entry.get("url"):
            print(f"  SKIP {toml}: no download URL (CurseForge-mode?)")
            continue
        local, was_dl = cached_jar(entry)
        dl += int(was_dl)
        with zipfile.ZipFile(local) as zf:
            structures, sets = scan_worldgen(zf)
        label = f"mod: {by_toml[toml][0]} ({entry['url'].rsplit('/', 1)[-1]})"
        _report_source(label, structures, sets)
        all_structures.update(structures)
        all_sets.update(sets)

    if scan_dp:
        dp_root = paxi_dir(pack_dir)
        if os.path.isdir(dp_root):
            for name in sorted(os.listdir(dp_root)):
                p = os.path.join(dp_root, name)
                if os.path.isdir(p):
                    # Re-zip the dir into memory via a temp zip so scan_worldgen
                    # works identically for dir and zip datapacks.
                    tmp = tempfile.mkdtemp(prefix="mc-dp-")
                    zip_path = os.path.join(tmp, "dp.zip")
                    with zipfile.ZipFile(zip_path, "w") as zf:
                        for root, _, files in os.walk(p):
                            for f in files:
                                full = os.path.join(root, f)
                                rel = os.path.relpath(full, p)
                                zf.write(full, rel)
                    with zipfile.ZipFile(zip_path) as zf:
                        structures, sets = scan_worldgen(zf)
                    shutil.rmtree(tmp, ignore_errors=True)
                    label = f"datapack: config/paxi/datapacks/{name}/"
                elif name.endswith(".zip"):
                    try:
                        with zipfile.ZipFile(p) as zf:
                            structures, sets = scan_worldgen(zf)
                    except zipfile.BadZipFile:
                        print(f"  SKIP datapack {name}: not a valid zip")
                        continue
                    label = f"datapack: config/paxi/datapacks/{name}"
                else:
                    continue
                if structures or sets:
                    _report_source(label, structures, sets)
                all_structures.update(structures)
                all_sets.update(sets)
        data_dir = os.path.join(pack_dir, "data")
        if os.path.isdir(data_dir):
            tmp = tempfile.mkdtemp(prefix="mc-dp-")
            zip_path = os.path.join(tmp, "pack-data.zip")
            with zipfile.ZipFile(zip_path, "w") as zf:
                for root, _, files in os.walk(data_dir):
                    for f in files:
                        full = os.path.join(root, f)
                        rel = os.path.relpath(full, data_dir)
                        zf.write(full, rel)
            with zipfile.ZipFile(zip_path) as zf:
                structures, sets = scan_worldgen(zf)
            shutil.rmtree(tmp, ignore_errors=True)
            _report_source("datapack: <pack>/data/", structures, sets)
            all_structures.update(structures)
            all_sets.update(sets)

    print()
    print(f"## summary ({dl} jar{'s' if dl != 1 else ''} downloaded, rest from cache)")
    print(f"  total structures:     {len(all_structures)}")
    print(f"  total structure sets: {len(all_sets)}")
    refd = {s for members in all_sets.values() for s in members}
    unrefd = sorted(k for k in all_structures if k not in refd)
    if unrefd:
        print(f"  structures NOT in any set (never spawn via sets — likely fine, "
              f"set-driven via code): {len(unrefd)}")
        for s in unrefd[:15]:
            print(f"    - {s}")
        if len(unrefd) > 15:
            print(f"    … ({len(unrefd) - 15} more)")
    missing = sorted(k for k in refd if k not in all_structures and not k.startswith("minecraft:"))
    if missing:
        print(f"  sets reference MISSING structures: {', '.join(missing)}")
    vanilla = sorted(k for k in all_structures if k.startswith("minecraft:"))
    if vanilla:
        print(f"  vanilla-overlapping structures (pack/mods redefine them): {len(vanilla)}")
        for v in vanilla:
            print(f"    - {v}")


# ── datapack subcommands ─────────────────────────────────────────────────────

def paxi_dir(pack_dir):
    return os.path.join(pack_dir, "config", "paxi", "datapacks")


def pack_format_ok(pack_dir, zip_path):
    """Validate pack.mcmeta pack_format against the pack's MC version."""
    mc = mc_version(pack_dir)
    want = PACK_FORMATS.get(mc)
    with zipfile.ZipFile(zip_path) as zf:
        meta = next((n for n in zf.namelist() if n.endswith("pack.mcmeta")), None)
        if meta is None:
            return False, f"{zip_path} has no pack.mcmeta — not a datapack?"
        import tomllib
        data = json.loads(zf.read(meta))
        got = data.get("pack", {}).get("pack_format")
    if want is None:
        return True, f"MC {mc}: no pack_format mapping known — can't validate"
    if got != want:
        return False, (f"pack_format {got} != expected {want} for MC {mc} "
                       f"(see https://minecraft.wiki/w/Pack_format)")
    return True, f"pack_format {got} matches MC {mc}"


def dir_pack_format_ok(pack_dir, pack_meta_path):
    """Validate a directory datapack's pack.mcmeta (same rules as a zip)."""
    mc = mc_version(pack_dir)
    want = PACK_FORMATS.get(mc)
    try:
        with open(pack_meta_path) as fh:
            got = json.load(fh).get("pack", {}).get("pack_format")
    except Exception as e:  # noqa: BLE001
        return False, f"unreadable pack.mcmeta: {e}"
    if want is None:
        return True, f"MC {mc}: no pack_format mapping known — can't validate"
    if got != want:
        return False, (f"pack_format {got} != expected {want} for MC {mc} "
                       f"(see https://minecraft.wiki/w/Pack_format)")
    return True, f"pack_format {got} matches MC {mc}"


def cmd_datapack_add(pack_dir, args):
    if len(args) < 1:
        die("datapack add <local-zip-or-dir> [--name <name>]")
    src = args[0]
    name = None
    i = 1
    while i < len(args):
        if args[i] == "--name" and i + 1 < len(args):
            name = args[i + 1]; i += 2
        else:
            die(f"unknown arg {args[i]}")
    if not os.path.exists(src):
        die(f"source {src} not found")
    if name is None:
        name = os.path.basename(src)
        if os.path.isfile(src) and not name.endswith(".zip"):
            name = os.path.splitext(name)[0]
    dest = os.path.join(paxi_dir(pack_dir), name)
    # Validate BEFORE copying so a bad datapack never leaves residue.
    if src.endswith(".zip"):
        ok, msg = pack_format_ok(pack_dir, src)
        if not ok:
            die(msg)
        print(msg)
    elif os.path.isdir(src):
        meta = os.path.join(src, "pack.mcmeta")
        if os.path.exists(meta):
            ok, msg = dir_pack_format_ok(pack_dir, meta)
            if not ok:
                die(msg)
            print(msg)
        else:
            print("dir datapack — no pack.mcmeta check")
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    if os.path.isdir(src):
        shutil.copytree(src, dest, dirs_exist_ok=True)
    else:
        shutil.copy2(src, dest)
    run_refresh(pack_dir)
    print(f"installed datapack to config/paxi/datapacks/{name} and refreshed the index")


def cmd_datapack_remove(pack_dir, args):
    if len(args) < 1:
        die("datapack remove <name>")
    name = args[0]
    dest = os.path.join(paxi_dir(pack_dir), name)
    if not os.path.exists(dest):
        die(f"config/paxi/datapacks/{name} not found")
    if os.path.isdir(dest):
        shutil.rmtree(dest)
    else:
        os.remove(dest)
    run_refresh(pack_dir)
    print(f"removed config/paxi/datapacks/{name} and refreshed the index")


# ── controls subcommand (default hotkeys / controls review) ──────────────────
# Minecraft stores every keybinding (vanilla + mods) in `options.txt` at the
# GAME ROOT (e.g. .minecraft/options.txt) as `key_<translation-key>:<code>`
# lines. A pack ships its own default by putting `options.txt` at the PACK ROOT
# (not under config/), which packwiz-installer maps 1:1 to the game root.
#
# Review ("controls") reads the effective bindings from a generated options.txt
# (the instance's, an explicit --options path, or the pack's shipped file) and
# resolves each keybind id to a label + owning mod via the pinned jars' lang
# files. Set ("controls-set") writes/edits the pack's options.txt.

VANILLA_CONTROL_IDS = {
    "key.attack", "key.use", "key.forward", "key.left", "key.back", "key.right",
    "key.jump", "key.sneak", "key.sprint", "key.drop", "key.inventory",
    "key.chat", "key.playerlist", "key.pickItem", "key.command", "key.screenshot",
    "key.togglePerspective", "key.smoothCamera", "key.fullscreen", "key.spectatorOutlines",
    "key.swapOffhand", "key.saveToolbarActivator", "key.loadToolbarActivator",
    "key.advancements", "key.hotbar.1", "key.hotbar.2", "key.hotbar.3", "key.hotbar.4",
    "key.hotbar.5", "key.hotbar.6", "key.hotbar.7", "key.hotbar.8", "key.hotbar.9",
    "key.socialInteractions", "key.screenshot",
}

KEY_DECODE = {
    "key.keyboard.unknown": "Unbound",
    "key.mouse.left": "LMB", "key.mouse.right": "RMB", "key.mouse.middle": "MMB",
    "key.keyboard.left.control": "LControl", "key.keyboard.right.control": "RControl",
    "key.keyboard.left.shift": "LShift", "key.keyboard.right.shift": "RShift",
    "key.keyboard.left.alt": "LAlt", "key.keyboard.right.alt": "RAlt",
    "key.keyboard.space": "Space", "key.keyboard.enter": "Enter", "key.keyboard.tab": "Tab",
    "key.keyboard.esc": "Escape", "key.keyboard.escape": "Escape",
    "key.keyboard.backspace": "Backspace",
    "key.keyboard.delete": "Delete", "key.keyboard.insert": "Insert",
    "key.keyboard.home": "Home", "key.keyboard.end": "End",
    "key.keyboard.page.up": "PageUp", "key.keyboard.page.down": "PageDown",
    "key.keyboard.up": "Up", "key.keyboard.down": "Down", "key.keyboard.left": "Left",
    "key.keyboard.right": "Right", "key.keyboard.slash": "Slash",
    "key.keyboard.backslash": "Backslash", "key.keyboard.semicolon": "Semicolon",
    "key.keyboard.comma": "Comma", "key.keyboard.period": "Period",
    "key.keyboard.apostrophe": "Apostrophe", "key.keyboard.left.bracket": "[",
    "key.keyboard.right.bracket": "]", "key.keyboard.minus": "Minus",
    "key.keyboard.equal": "Equals", "key.keyboard.grave": "Grave",
    "key.keyboard.caps.lock": "CapsLock", "key.keyboard.num.lock": "NumLock",
    "key.keyboard.scroll.lock": "ScrollLock", "key.keyboard.pause": "Pause",
    "key.keyboard.print.screen": "PrintScreen",
    "key.keyboard.keypad.enter": "KeypadEnter", "key.keyboard.keypad.add": "KeypadPlus",
    "key.keyboard.keypad.subtract": "KeypadMinus", "key.keyboard.keypad.multiply": "KeypadStar",
    "key.keyboard.keypad.divide": "KeypadSlash", "key.keyboard.keypad.decimal": "KeypadDot",
}
for _i in range(10):
    KEY_DECODE[f"key.keyboard.keypad.{_i}"] = f"Keypad{_i}"
for _i in range(1, 26):
    KEY_DECODE[f"key.keyboard.f{_i}"] = f"F{_i}"
for _c in "abcdefghijklmnopqrstuvwxyz":
    KEY_DECODE[f"key.keyboard.{_c}"] = _c.upper()
for _i in range(10):
    KEY_DECODE[f"key.keyboard.{_i}"] = str(_i)


def decode_key(code):
    # Minecraft binds can carry a modifier suffix, e.g. "key.keyboard.p:CONTROL".
    base = code.split(":", 1)[0]
    mod = code.split(":", 1)[1] if ":" in code else ""
    decoded = KEY_DECODE.get(base, base)
    return f"{decoded}+{mod.title()}" if mod else decoded


def find_options_file(pack_dir, explicit=None, data_dir=None):
    """Locate an options.txt to review. Priority: explicit path, then the
    pack's shipped <pack>/options.txt, then a Prism instance's generated one
    (auto-detected from common data dirs). Returns (path, kind) or (None, why)."""
    if explicit:
        return explicit, "explicit"
    shipped = os.path.join(pack_dir, "options.txt")
    if os.path.isfile(shipped):
        return shipped, "pack"
    if data_dir is None:
        data_dir = os.environ.get("PRISMLAUNCHER_DIR", "")
    candidates = [
        data_dir or "",
        "/mnt/media/Modding/PrismLauncher",
        "/mnt/data/prismlauncher",
        os.path.expanduser("~/.local/share/PrismLauncher"),
        os.path.expanduser("~/.var/app/org.prismlauncher.PrismLauncher/data/PrismLauncher"),
    ]
    pack_name = os.path.basename(pack_dir.rstrip("/"))
    for base in candidates:
        inst = os.path.join(base, "instances")
        if not os.path.isdir(inst):
            continue
        for d in os.listdir(inst):
            if d.lower() != pack_name.lower():
                continue
            p = os.path.join(inst, d, ".minecraft", "options.txt")
            if os.path.isfile(p):
                return p, "instance"
    return None, "no options.txt found — launch the pack once (mc-run monitor=boot) to generate one, or pass --options <path>"


def parse_options_keybinds(text):
    """Parse options.txt text into an ordered dict of {keybind_id: keycode}.
    Ignores non key_* lines (sound, video, etc.)."""
    out = {}
    for line in text.splitlines():
        line = line.strip()
        if not line.startswith("key_"):
            continue
        id_, _, code = line.partition(":")
        out[id_[len("key_"):]] = code
    return out


def scan_lang_labels(pack_dir, ids):
    """Resolve keybind ids to (label, modid) by scanning the pinned jars' lang
    files (assets/<modid>/lang/en_us.json) for the id as a translation key.
    Returns {id: (label, modid)}. Only jars whose modid/name matches the id's
    modid segment are downloaded (cached via cached_jar). Ids are either
    "<modid>.<name>" (e.g. iris.keybind.reload) or "key.<modid>.<name>" (e.g.
    key.ae2.wireless_terminal)."""
    def modid_of(i):
        parts = i.split(".")
        if len(parts) >= 3 and parts[0] == "key":
            return parts[1]
        return parts[0] if len(parts) >= 2 else None

    mods = find_mod_jars(pack_dir)
    owners = {}
    for i in ids:
        seg = modid_of(i)
        if not seg or seg in ("key", "keyboard", "gui", "gui_mod"):
            continue
        matches = [k for k in mods if seg in k.lower() or k in seg.lower()]
        if matches:
            owners.setdefault(mods[matches[0]]["pw_toml"], seg)
    labels = {}
    for toml, seg in owners.items():
        entry = next((mods[k] for k in mods if mods[k]["pw_toml"] == toml), None)
        if not entry or not entry.get("url"):
            continue
        try:
            local, _ = cached_jar(entry)
            with zipfile.ZipFile(local) as zf:
                for n in zf.namelist():
                    m = re.match(r"^assets/([^/]+)/lang/en_us\.json$", n)
                    if not m:
                        continue
                    lang = json.loads(zf.read(n))
                    for i in ids:
                        if i in lang:
                            labels[i] = (str(lang[i]), m.group(1))
        except Exception:  # noqa: BLE001
            continue
    return labels


def cmd_controls(pack_dir, args):
    """controls [--options <path>] [--dataDir <dir>] [--mod <slug>]
    Review the default hotkeys/controls for the whole modpack: reads the
    effective bindings (pack-shipped options.txt, a generated instance
    options.txt, or an explicit path) and resolves every keybind to a label +
    owning mod via the pinned jars' lang files."""
    explicit = None
    data_dir = None
    mod_filter = None
    i = 0
    while i < len(args):
        a = args[i]
        if a == "--options" and i + 1 < len(args):
            explicit = args[i + 1]; i += 2
        elif a == "--dataDir" and i + 1 < len(args):
            data_dir = args[i + 1]; i += 2
        elif a == "--mod" and i + 1 < len(args):
            mod_filter = args[i + 1].lower(); i += 2
        else:
            die(f"unknown arg {a}")

    shipped = os.path.join(pack_dir, "options.txt")
    path, kind = find_options_file(pack_dir, explicit, data_dir)
    if path is None:
        die(kind)
    text = open(path, encoding="utf-8", errors="replace").read()
    binds = parse_options_keybinds(text)
    if not binds:
        print(f"{path} (source: {kind}) has no key_* lines — nothing to review.")
        return

    labels = scan_lang_labels(pack_dir, list(binds)) if not mod_filter else {}
    total = len(binds)
    vanilla = {k: v for k, v in binds.items() if k in VANILLA_CONTROL_IDS}
    mod = {k: v for k, v in binds.items() if k not in VANILLA_CONTROL_IDS}
    if mod_filter:
        def matches(id_):
            parts = id_.split(".")
            seg = parts[1] if len(parts) >= 3 and parts[0] == "key" else parts[0]
            return mod_filter in seg.lower() or mod_filter in id_.lower()
        mod = {k: v for k, v in mod.items() if matches(k)}
        total = len(vanilla) + len(mod)

    print(f"## controls for {os.path.basename(pack_dir)}  (source: {path})")
    if os.path.isfile(shipped):
        idx = read_index(pack_dir) or ""
        blk = index_entry(idx, "options.txt")
        state = "preserve" if blk and re.search(r"^preserve\s*=\s*true", blk, re.M) else "overwrite"
        print(f"  pack ships options.txt ({state}) — reviewed below is what players get")
    else:
        print("  pack does NOT ship options.txt — players get engine+mod defaults (shown below)")
    print(f"  keybindings: {total} (vanilla {len(vanilla)}, mod {len(mod)})")
    for grp, items in (("vanilla", vanilla), ("mod", mod)):
        if not items:
            continue
        print(f"\n## {grp}")
        for id_, code in sorted(items.items()):
            label = labels.get(id_, ("", ""))[0] if not mod_filter else ""
            owner = labels.get(id_, ("", ""))[1] if not mod_filter else ""
            if not label:
                label = id_
            own = f" [{owner}]" if owner else ""
            print(f"  {id_:<44} {decode_key(code):<12} {label}{own}")
    conflicts = {}
    for id_, code in binds.items():
        if code != "key.keyboard.unknown":
            conflicts.setdefault(code, []).append(id_)
    dups = {c: v for c, v in conflicts.items() if len(v) > 1}
    if dups:
        print("\n## conflicts (same key bound twice)")
        for code, ids in sorted(dups.items()):
            print(f"  {decode_key(code):<12} -> {', '.join(ids)}")


def cmd_controls_set(pack_dir, args):
    """controls-set [--key key_<id>=<code> ...] [--from <file>] [--preserve]
    Write/edit the pack's default options.txt (pack root → game root). --key
    sets/updates one keybind line each; --from seeds the file from a generated
    options.txt (e.g. a tuned instance's) to copy non-key settings too."""
    from_file = None
    preserve = False
    overrides = {}
    i = 0
    while i < len(args):
        a = args[i]
        if a == "--from" and i + 1 < len(args):
            from_file = args[i + 1]; i += 2
        elif a == "--key" and i + 1 < len(args):
            kv = args[i + 1]
            if "=" not in kv:
                die(f"--key expects key_<id>=<code>, got '{kv}'")
            k, v = kv.split("=", 1)
            overrides[k] = v; i += 2
        elif a == "--preserve":
            preserve = True; i += 1
        else:
            die(f"unknown arg {a}")
    if not overrides and not from_file:
        die("nothing to set — use --key key_<id>=<code> ... or --from <file>")

    dest = os.path.join(pack_dir, "options.txt")
    existing = open(dest).read() if os.path.isfile(dest) else ""
    base = open(from_file).read() if from_file and os.path.isfile(from_file) else existing
    lines = base.splitlines() if base else []
    by_id = {}
    for ln in lines:
        if ln.startswith("key_"):
            id_, _, code = ln.partition(":")
            by_id[id_[len("key_"):]] = ln
    for id_, code in overrides.items():
        clean = id_[len("key_"):] if id_.startswith("key_") else id_
        by_id[clean] = f"key_{clean}:{code}"
    kept = [ln for ln in lines if not ln.startswith("key_")]
    final = kept + sorted(by_id.values())
    with open(dest, "w") as fh:
        fh.write("\n".join(final) + "\n")
    run_refresh(pack_dir)
    lines_out = [f"wrote {dest} ({len(final)} lines, {len(by_id)} keybindings) and refreshed the index"]
    if preserve:
        lines_out.append(set_preserve(pack_dir, "options.txt", True))
    print("\n".join(lines_out))


# ── inspect (Modrinth API) ───────────────────────────────────────────────────

def _api(path):
    req = urllib.request.Request(f"{MODRINTH_API}{path}",
                                 headers={"User-Agent": "nixos-config-mc/1.0"})
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.loads(r.read())


def cmd_inspect(pack_dir, args):
    if len(args) < 1:
        die("inspect <mod-slug-or-name> [--jar]")
    slug = args[0]
    do_jar = "--jar" in args
    try:
        proj = _api(f"/project/{slug}")
    except Exception as e:  # noqa: BLE001
        die(f"Modrinth lookup failed for '{slug}': {e}")
    print(f"{proj['title']} ({proj['slug']})")
    print(f"  side: {proj.get('client_side')}/{proj.get('server_side')}")
    print(f"  downloads: {proj.get('downloads', 0):,} | follows: {proj.get('follows', 0):,}")
    print(f"  categories: {', '.join(proj.get('categories', [])[:8])}")
    mc = mc_version(pack_dir) or "1.21.1"
    # Prefer the pack's actual loader (pack.toml [versions]) so the API query
    # returns the right variant even when a project lists several.
    ptxt = read_pack_toml(pack_dir)
    loader = "neoforge"
    if re.search(r"^fabric\s*=", ptxt, re.M):
        loader = "fabric"
    elif re.search(r"^forge\s*=", ptxt, re.M):
        loader = "forge"
    try:
        ver = _api(f"/project/{slug}/version?loaders=[\"{loader}\"]&game_versions=[\"{mc}\"]")
    except Exception:  # noqa: BLE001
        ver = []
    if not ver:
        try:
            ver = _api(f"/project/{slug}/version")
        except Exception:  # noqa: BLE001
            ver = []
    if ver:
        v = ver[0]
        print(f"  version: {v.get('version_number')} ({loader}, MC {mc})")
        deps = v.get("dependencies", [])
        if deps:
            for d in deps:
                kind = d.get("dependency_type", "?")
                tgt = d.get("project_id") or d.get("version_id") or "?"
                print(f"    dep [{kind}]: {tgt}")
        else:
            print("  deps: none")
    if do_jar and ver:
        files = ver[0].get("files", [])
        if files:
            jar_url = files[0]["url"]
            tmp = tempfile.mkdtemp(prefix="mc-inspect-")
            jar = os.path.join(tmp, "mod.jar")
            try:
                print(f"  downloading jar to list config files…")
                urllib.request.urlretrieve(jar_url, jar)
                with zipfile.ZipFile(jar) as zf:
                    cfg = sorted(n for n in zf.namelist() if n.startswith("config/") and n.endswith((".toml", ".cfg", ".json", ".properties")))
                print(f"  config files shipped: {len(cfg)}")
                for c in cfg[:25]:
                    print(f"    {c}")
                if len(cfg) > 25:
                    print(f"    … and {len(cfg) - 25} more")
            finally:
                shutil.rmtree(tmp, ignore_errors=True)


COMMANDS = {
    "config-add": cmd_config_add,
    "config-preserve": cmd_config_preserve,
    "config-list": cmd_config_list,
    "config-diff": cmd_config_diff,
    "config-show": cmd_config_show,
    "jar-meta": cmd_jar_meta,
    "structures": cmd_structures,
    "controls": cmd_controls,
    "controls-set": cmd_controls_set,
    "datapack-add": cmd_datapack_add,
    "datapack-remove": cmd_datapack_remove,
    "inspect": cmd_inspect,
}


def main():
    if len(sys.argv) < 3:
        die("usage: mc-pack.py <modpack-dir> <command> [args…]")
    pack_dir, cmd = sys.argv[1], sys.argv[2]
    if not os.path.isdir(os.path.join(pack_dir, "pack.toml")) and not os.path.exists(os.path.join(pack_dir, "pack.toml")):
        if not os.path.isdir(pack_dir):
            die(f"{pack_dir} is not a directory")
    handler = COMMANDS.get(cmd)
    if handler is None:
        die(f"unknown command {cmd} (expected: {', '.join(sorted(COMMANDS))})")
    handler(pack_dir, sys.argv[3:])


if __name__ == "__main__":
    main()
