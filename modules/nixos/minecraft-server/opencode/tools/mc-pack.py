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
