---
name: mc-mod-patch
description: Use when a mod in a packwiz modpack in this repo needs a jar-level patch because its embedded metadata cannot be controlled by config — fixing a dependency versionRange or dependency list in META-INF/neoforge.mods.toml at Nix build time. Covers reading the pinned jar's metadata with packwiz-jar-meta, writing the fail-loud patches/<mod>.py script, registering it in patches.nix, and verifying the patched jar ships to both client and server.
---

# Mod Jar Patches (packwiz)

Some mod problems live in the jar's **embedded metadata**
(`META-INF/neoforge.mods.toml`), which no config file can influence: a
dependency `versionRange` that pins a version that doesn't exist for the
pack's MC version, a dependency that must be present, a wrong loader range.
Config changes (`mc-mod-config-set` skill) and datapack/KubeJS patches can't
touch this. Fix it by patching the jar **at Nix build time** — the change
lives in the pack directory (reproducible), not in any runtime location.

The pack's `.pw.toml` / `index.toml` / `checksums.json` stay byte-identical:
the pack remains a pure list of upstream mods, and the patch re-applies after
every `packwiz update`.

## How the infra works

- `patch-jar.nix` (`modules/nixos/minecraft-server/modpacks/patch-jar.nix`)
  — `patchJar { name, src, patchScript, member? }` unzips one member
  (default `META-INF/neoforge.mods.toml`), runs the Python script on it, and
  re-zips byte-identically (member mtime pinned to epoch). Deliberately a
  member replacement, not a full unzip/rezip.
- `<pack>/patches.nix` — maps `"mods/<checksums-key-stem>.jar"` →
  `patchJar { ... }`. Imported by BOTH the client
  (`modules/flake-parts/packwiz.nix` `mkClientInstance`) and the server
  (`modules/nixos/minecraft-server/config.nix` `packwizSymlinks`), so one
  patch definition ships the same jar to both sides.
- `<pack>/patches/<mod>.py` — the actual edit. Must **fail loudly** (exit 1)
  when the expected content is missing, so an upstream metadata change is
  caught instead of silently shipping an unpatched jar.

## Tools

- `packwiz-jar-meta <pack> <mod> [member]` — **read the pinned jar's metadata**:
  prints `META-INF/neoforge.mods.toml` from the exact jar in `checksums.json`
  (what players get). Write the patch against these bytes, never Modrinth's
  latest. If the member is missing, lists the jar's `META-INF/*.toml`.
- `mc-prism-log <pack> log=crash` — the launch failure that motivated the patch
  (the FML error names the mod and the bad `versionRange`).
- `nix build .#minecraft-modpack-<pack>` — build the client content; a failing
  patch script fails the build (that's the fail-loud guarantee).
- `mc-run <pack> monitor=boot` — launch the built pack to confirm the mod now
  loads.

## Workflow: create a patch

1. **Diagnose.** Read the crash/load error (`mc-prism-log`). Identify the mod
   and the exact offending metadata (e.g. `mr_still_life versionRange="[1,)"`
   when Still Life's real 1.21.1 release is 0.1.1).
2. **Read the pinned metadata** — `packwiz-jar-meta <pack> <mod>`. This is the
   byte-accurate source of truth for the patch.
3. **Decide patch vs other fixes:**
   - Patch = metadata the mod declares about itself that is wrong for this pack
     (dependency ranges, required deps). The mod is otherwise fine.
   - Config/scripts (`mc-mod-config-set`) = runtime settings.
   - Removal is the LAST resort, only for a genuine upstream incompatibility
     (e.g. a jar compiled against a different major library version) — and
     record why in the commit.
4. **Write `<pack>/patches/<mod>.py`** following the conventions below.
5. **Register in `<pack>/patches.nix`**:
   ```nix
   { mods, patchJar }: {
     "mods/dynamic-trees-still-life.jar" = patchJar {
       name = "dtstill-life-1.0.3-patched";
       src = mods."dynamic-trees-still-life.pw.toml";   # pinned upstream fetch
       patchScript = ./patches/dynamic-trees-still-life.py;
     };
   }
   ```
   - Key: `"mods/"` + checksums.json key with `.pw.toml` → `.jar`
     (i.e. the pw.toml stem + `.jar`), matching `mkModLinks` output.
   - `src` = `mods."<checksums key>"` — the same pinned store path packwiz2nix
     built from `checksums.json`.
   - `member` is optional; add it only if you're patching something other than
     the default `META-INF/neoforge.mods.toml`.
6. **Stage it** — `git add modules/nixos/minecraft-server/modpacks/<pack>`
   (flakes only snapshot tracked files; without staging, the patch file is
   invisible to the build).
7. **Verify:**
   - `nix build .#minecraft-modpack-<pack>` succeeds (the patch script ran and
     found its target).
   - Inspect the built jar: resolve
     `<store>/.../.minecraft/mods/<patched>.jar` and read its
     `META-INF/neoforge.mods.toml` to confirm the change.
   - `mc-run <pack> monitor=boot` — mod loads cleanly.
   - If the pack runs a server, `nixos-rebuild switch` on the host (the server
     symlinks the same patched jars) and restart the server unit.
8. **Report:** mod, the exact metadata changed (before → after), the patch
   file + patches.nix key, build/launch verification.

## Patch script conventions

```python
#!/usr/bin/env python3
"""Fix <Mod>'s embedded dependency range.

Usage: <mod>.py <META-INF/neoforge.mods.toml>

<One or two sentences: the bug in upstream metadata and the fix.>

Fails loudly if the expected line is missing, so an upstream metadata change
is caught instead of silently producing an unpatched jar.
"""
import re
import sys

path = sys.argv[1]
with open(path, encoding="utf-8") as f:
    text = f.read()

new, n = re.subn(r'(versionRange\s*=\s*")\[1,\)(")', r"\g<1>[0.1,)\g<2>", text)
if n != 1:
    sys.stderr.write(
        f"expected exactly one versionRange=\"[1,)\" line, found {n}; "
        "re-review upstream metadata (<Mod>)\n"
    )
    sys.exit(1)

with open(path, "w", encoding="utf-8") as f:
    f.write(new)
```

- `sys.argv[1]` is the member file path (unzipped by `patch-jar.nix`).
- Match **exactly one** occurrence (`re.subn`, assert `n == 1`) — a change in
  upstream metadata changes the match count and trips the fail-loud guard.
- Anchor the regex on enough context (the `modId` + `versionRange` together)
  so you don't patch the wrong dependency's range.
- `sys.exit(1)` with a message naming the mod and what to re-review.

## Gotchas

- **Use the pinned metadata** (`packwiz-jar-meta`), not a doc page or
  Modrinth's latest jar — the patch must match the bytes the pack pins.
- **Fail loud or not at all.** A patch that silently no-ops ships an unpatched
  jar and the crash persists — the `n == 1` guard is mandatory.
- **Patch, don't remove** — the pack owner wants mods kept; only remove for a
  real upstream incompatibility, and say so in the commit.
- **Both sides get it** — client and server import the same `patches.nix`; do
  not hand-patch the Prism instance or a store path. Rebuild, don't hand-edit.
- The patches.nix key must match `mkModLinks` output exactly — the pw.toml
  stem + `.jar`, NOT the jar's `filename` field (they can differ; check the
  checksums key).
- A `versionRange` that's merely "too wide" (e.g. `[1,)` accepting anything
  ≥1.0) needs the range widened to cover the real release — you're relaxing a
  constraint, not fabricating a version.

## Example (from this repo)

`Dynamic Trees - Still Life 1.0.3` pinned `mr_still_life` to `[1,)`, but Still
Life's 1.21.1 release is 0.1.1. `packwiz-jar-meta AllTheTech
dynamic-trees-still-life` showed the exact line; the patch widened it to
`[0.1,)`; registered in `patches.nix` as
`"mods/dynamic-trees-still-life.jar"` with
`src = mods."dynamic-trees-still-life.pw.toml"`. The built client symlinks
`dynamic-trees-still-life.jar → dtstill-life-1.0.3-patched`, and the metadata
reads `mr_still_life versionRange="[0.1,)"`, matching Still Life 0.1.1.
