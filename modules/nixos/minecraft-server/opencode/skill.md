---
name: mc-modpack
description: Use when working with packwiz modpacks in this repo — adding/removing/updating mods, generating checksums.json, converting CurseForge mods to Modrinth or direct URLs, verifying pack consistency, shipping default player configs, adding Paxi datapack patches, or deploying a modpack to a minecraft-server module host.
---

# Minecraft Modpack Management (packwiz)

This repo runs Minecraft servers via `my.services.minecraftServer`
(`modules/nixos/minecraft-server/`). Modpacks are authored with the
[packwiz CLI](https://packwiz.infra.link) and turned into Nix fixed-output
derivations by [packwiz2nix](https://github.com/getchoo/packwiz2nix).

## Where modpacks live

Each modpack is a directory under
`modules/nixos/minecraft-server/modpacks/<name>/`:

```
<name>/
├── pack.toml          # name, author, version, [versions] minecraft + loader,
│                      #   [options] (e.g. datapack-folder for Paxi)
├── index.toml         # sha256 index of every metadata + internal file (keep in sync)
├── checksums.json     # { "<file>.pw.toml": {url, sha256} } — built by Nix
├── .packwizignore     # files packwiz must NOT index (e.g. checksums.json)
├── mods/*.pw.toml     # one metadata file per mod (name, filename, [download] url/hash)
└── config/            # internal files copied to players: default configs, Paxi datapacks
```

## Available tools / commands

These are added to opencode automatically when the minecraft-server module is
enabled:

- `packwiz` tool — run the packwiz CLI inside a modpack (e.g. `modrinth add sodium`,
  `refresh`, `list`, `update --all`, `remove <file>.pw.toml`).
- `packwiz-checksums` tool — regenerate `checksums.json` (downloads every jar,
  sha256-pins them). **Run after any mod change; commit the file.**
- `mc-pack-status` tool — verify the pack (index sync, checksums coverage,
  CurseForge-mode count, duplicate jars, internal files indexed, datapack
  pack_format).
- **Config tooling** (default player configs):
  - `packwiz-config-add` — write/overwrite a file under `config/` (e.g.
    `jei/jei.toml`) and refresh the index; optional `--preserve`.
  - `packwiz-config-preserve` — set/clear `preserve` on an index entry. Preserve
    = install the file only if it doesn't already exist, so player edits win.
  - `packwiz-config-list` — inventory shipped configs (+ preserve state).
  - `packwiz-config-diff` — diff the pack's override against the owning mod's
    stock default config (downloaded from the jar).
  - `packwiz-config-show` — review/get a **specific mod's** config from its
    pinned jar: lists the config/ files it ships (sizes + whether the pack
    overrides each) and prints a chosen file's contents. The basis for the
    `mc-mod-config` skill's review workflow.
- **Patch tooling** (datapacks via Paxi):
  - `packwiz-datapack-add` — add a local datapack to `config/paxi/datapacks/`,
    validating pack.mcmeta pack_format against the pack's MC version.
  - `packwiz-datapack-remove` — remove one.
- **Jar-patch tooling** (metadata config can't control):
  - `packwiz-jar-meta` — print a mod's pinned `META-INF/neoforge.mods.toml`
    (the bytes a build-time patch must match). The basis for the
    `mc-mod-patch` skill's workflow (write `patches/<mod>.py`, register in
    `patches.nix`).
  - **Source-patching** (compiled-logic config/metadata can't control) — not a
    single tool: `buildModSource` helper
    (`modules/nixos/minecraft-server/modpacks/build-mod-source.nix`) builds a
    whole mod from source via a fixed-output derivation (`:neoforge:build` with
    the mod's own gradle wrapper). Per-mod modules live under
    `<pack>/source-patches/<mod>/` (`default.nix` + git-format `.patch`),
    registered in `patches.nix` under the same `"mods/<key>.jar"` keys, and
    consumed by both client and server. The basis for the `mc-mod-source-patch`
    skill (e.g. RoadWeaver's elevated-water fix).
- **Structure review tooling** (worldgen):
  - `packwiz-structures` — review every worldgen structure + structure set the
    pack generates, scanned from the pinned mod jars and the pack's own
    datapacks (Paxi + `data/`). Lists structures with type/biome tag, sets
    with the structures they spawn, flags referenced-but-missing structures,
    and flags `minecraft:`-namespace redefinitions (vanilla overrides). Jar
    downloads are cached by checksum so full-pack re-runs are instant. The
    basis for the `mc-mod-structures` skill's review workflow.
- **Controls tooling** (default hotkeys/controls):
  - `packwiz-controls` — review the default hotkeys/controls for the whole
    pack: reads the effective `options.txt` (pack-shipped → instance-generated
    → explicit path), decodes every `key_*` binding, resolves ids to labels +
    owning mods via pinned jar lang files, splits vanilla vs mod, and reports
    conflicts (same key bound twice). Basis for the `mc-mod-controls` skill.
  - `packwiz-controls-set` — ship/override default controls by writing the
    pack's `options.txt` at the PACK ROOT (game root on install, NOT
    `config/`), refreshing the index, with optional `preserve`. `keys=` rebinds
    specific keybindings; `from=` seeds a tuned generated file. Basis for the
    `mc-mod-controls-set` skill.
- **Version / QA tooling**:
  - `packwiz-mod-pin` — pin/unpin a mod (pinned = never auto-updated).
  - `packwiz-inspect-mod` — Modrinth API: side, deps, the version for the pack's
    loader+MC; `--jar` lists the config files the mod ships.
  - `packwiz-update-safe` — `update --all` → checksums → verify → git add, one shot.
  - `mc-prism-log` — read the latest Minecraft log (`latest.log` / `debug.log` /
    newest crash report) for a modpack's Prism Launcher instance. Use to
    diagnose a launch crash or startup error. Auto-detects the Prism data dir
    (`/mnt/media/Modding/PrismLauncher`, `/mnt/data/prismlauncher`,
    `~/.local/share/PrismLauncher`, `$PRISMLAUNCHER_DIR`); pass `dataDir` to
    override. Options: `log` (latest/debug/crash/all), `filter` (regex),
    `tail` (lines). **Fallback:** when Prism Launcher is not available on the
    host, reads the dedicated server logs instead — on-disk
    `<dataDir>/<server>/logs/latest.log` plus `journalctl -u
    minecraft-server-<server>`. The server name is auto-detected from the
    repo's servers config, or pass `server` explicitly.
  - `mc-run` — run a modpack. Uses Prism Launcher if available (binary +
    instance present): `prismlauncher --launch <modpack>` detached, logs under
    the instance's `.minecraft/logs`. Otherwise a native fallback: starts the
    dedicated `minecraft-server-<server>` unit if configured for the pack,
    else builds the client content (`nix build .#minecraft-modpack-<name>`)
    for a manual launch. `server` and `dataDir` are optional overrides;
    `forceNative` skips Prism. **Auto-close / monitoring:**
    `timeout=<seconds>` closes the instance after N seconds (0/omitted = run
    indefinitely); `monitor=<'boot'|'crash'|regex>` watches the log after
    launching and exits (closing the instance) as soon as the indicator is
    seen, a crash appears, or `timeout` elapses — use to confirm a pack boots
    or fails, e.g. `monitor=crash` to wait for a launch crash.
  - `mc-install` — build a modpack's client content via the flake part
    (`.#minecraft-modpack-<name>` package / `.#modpack-build-<name>` app) and
    install it into the Prism instance, but ONLY when it has actually changed.
    Builds to a store path, compares against the installed instance with the
    same methodology as `packwiz-instance-sync.py` (mods dir full-mirror with
    `--delete`, internal dirs seeded-once, `instance.cfg` MC/loader versions),
    then calls `nix run .#modpack-build-<name>` only if differences exist.
    `dryRun=true` reports the diff without installing; `force=true` reinstalls
    regardless; `server` writes `[JoinServerOnLaunch]`.
- `mc-modpack` command — orchestrated workflow for a requested modpack change.

 ### Self-improvement (mc-run, mc-prism-log, mc-install, packwiz-structures, packwiz-controls, packwiz-controls-set & packwiz-config-add)

All seven carry a self-improvement protocol like the researcher agent: theirsource is the repo file
`modules/nixos/minecraft-server/opencode/tools/<tool>.ts` (the runtime copy in
`~/.config/opencode/tools/` is a read-only store symlink). When using any of
them surfaces a bug or a missing feature, **edit the repo `.ts` file directly**
and append a `// ## RUN LOG` entry (dated, one-line title + lesson/fix),
mirroring the RUN LOG convention. You can also pass `note=<text>` to any of
them to append a RUN LOG entry programmatically without a manual edit — a note
appends to BOTH the tool source AND the tool's paired skill doc
(`skill-mc-mod-structures.md` for packwiz-structures, `skill-mc-mod-controls*.md`
for packwiz-controls*, `skill-mc-mod-config-set.md` for packwiz-config-add,
`skill.md` for the mc-* launchers).
Note: when you append a RUN LOG entry by hand, place it at the very end of the
file AFTER the `export default` block — never mid-file, and never remove the
`// ## RUN LOG` marker from inside the `appendRunLog` template literal.
- Just recipes: `just packwiz <pack> <cmd>`, `just packwiz-checksums <pack>`.

## Workflow

1. `packwiz init` the pack (NeoForge/Fabric; must match the server's `package`).
2. `packwiz modrinth add <mod>` to add mods (dependencies auto-added).
3. `packwiz refresh` after manual file edits (configs, datapacks, …).
4. `git add` the pack files — **Nix flakes only snapshot tracked files**, so new
   `.pw.toml`/`checksums.json`/config files are invisible to eval until staged.
5. `packwiz-checksums` → regenerates `checksums.json`; commit it.
6. `mc-pack-status` → confirm "READY for Nix build".

### Default player configs

Drop files under `config/<mod>/<file>` (the pack's `config/` dir) and refresh —
packwiz installers copy them over the mod's generated config on install. Decide
per-file whether to set `preserve`:

- `preserve = true` → written only if absent; players keep their edits forever.
  Good for defaults you don't want clobbered, but note existing players will
  never receive later improvements to that file.
- no flag (default) → overwrites on every reinstall. Good for configs that must
  match the pack (e.g. ones a datapack or KubeJS script depends on).

For the full write-reproducibly workflow (baseline → edit → write → preserve
decision → verify → git add), load the `mc-mod-config-set` skill — it enforces
that config edits always land in the pack dir, never in a running instance or
built pack.

### Patches via Paxi datapacks

`config/paxi/datapacks/` is loaded into every world by Paxi (server-side too).
A custom datapack is a zip (or dir) with a `pack.mcmeta` whose `pack_format`
must match the pack's MC version — **1.21.1 = 48**. Remember the 1.21.1 folder
renames when writing recipe/loot patches: `loot_tables` → `loot_table`,
`tags/items` → `tags/item`, `functions` → `function`. KubeJS (`kubejs/`) and
CraftTweaker (`scripts/`) are the script-based patch alternative.

## Gotchas

- **Don't remove mods by default — patch instead.** The modpack owner does not
  want mods removed to dodge a dependency conflict. When a mod fails to load
  because its embedded dependency range is wrong (e.g. it pins `mr_still_life`
  `[1,)` but Still Life has no 1.0+ release for the pack's MC version), fix the
  jar's metadata at Nix build time rather than dropping the mod:
  1. Add a patch script under `<pack>/patches/<mod>.py` (edits
     `META-INF/neoforge.mods.toml`; must fail loudly if the expected line is
     missing) and register it in `<pack>/patches.nix`.
  2. The patch is applied by `modules/nixos/minecraft-server/modpacks/
     patch-jar.nix` from the SAME pinned upstream fetch, for both the client
     (`packwiz.nix mkClientInstance`) and the server
     (`minecraft-server/config.nix packwizSymlinks`). `.pw.toml`/`index.toml`/
     `checksums.json` stay byte-identical.
  3. `git add` the new files — flakes only see tracked files.
  Load the `mc-mod-patch` skill for the full workflow
  (`packwiz-jar-meta` → patch script → patches.nix → verify both sides).
  Only remove a mod when the conflict is a real upstream incompatibility (e.g.
  a jar compiled against a different major version of a library, like
  sodium-core-shader-support pinned to sodium 0.6.13 in a sodium 0.8 pack), and
  record why in the commit.

- **Some bugs need a source patch, not a metadata patch.** When the problem is
  in compiled Java logic (water detection, terrain, behaviour) that no config
  file, datapack, or `neoforge.mods.toml` edit can express, build the mod from
  source with a source-level patch instead:
  1. Write `<pack>/source-patches/<mod>/default.nix` (`buildModSource` with a
     pinned `fetchFromGitHub` src, the `.patch` file, and an FOD `outputHash`)
     plus the git-format diff.
  2. Register it in `<pack>/patches.nix` under the same
     `"mods/<checksums-key>.jar"` key as a `buildModSource` entry.
  3. `.packwizignore` must exclude `source-patches/`.
  4. Compute `outputHash` via `nix build --impure .#minecraft-modpack-<pack>`
     (FODs need `--impure`; the first run prints the `got:` hash).
  Load the `mc-mod-source-patch` skill for the full workflow (pinned rev →
  patch → module → patches.nix → FOD hash → verify both sides).

- **CurseForge mods break the Nix build.** packwiz stores them as
  `mode = "metadata:curseforge"` with **no download URL** in `[download]`.
  `packwiz-checksums` fails on them. Convert them:
  - Prefer `packwiz modrinth add <slug>` if the mod exists on Modrinth.
  - Otherwise `packwiz url add <direct-url>` — the CurseForge CDN URL is
    derivable from the file-id: `https://edge.forgecdn.net/files/<id//1000>/<id%1000>/<filename>`
    (then remove the old `*.pw.toml`).
- **Loader/version must match.** A NeoForge 1.21.1 pack can't include
  Fabric-only or client-only mods (packwiz errors "no valid versions found").
- `packwiz curseforge add <numeric-id>` treats the number as a search term and
  returns "No projects found" — use `--addon-id <id>` or the slug/URL form.
- **Every config/datapack edit needs `packwiz refresh`** — it re-hashes the file
  into index.toml. Files on disk but not in the index silently never reach
  players (mc-pack-status flags these).
- `checksums.json` lives at the pack root and must be in `.packwizignore` or
  packwiz will index it as an internal file.
- Datapack `pack_format` must match the pack's MC version (1.21.1 = 48); wrong
  numbers show the pack as incompatible.
- The flake's checksum app and `packwiz` CLI are exposed as
  `.#packwiz` / `.#packwiz-checksums-<pack>` (see `modules/flake-parts/packwiz.nix`).

## Wiring a pack to a server

Set `servers.<name>.packwiz = ../modpacks/<pack>` in a server definition; the
module reads `<pack>/checksums.json`, builds every mod, and symlinks them into
the server's `mods/` at start. The pack's `config/` (default player configs) and
Paxi datapacks, `kubejs/` and `scripts/` are symlinked into the data dir too. The
server's `package` (loader + MC version) must match the pack's `pack.toml`.

## RUN LOG

### 2026-08-14
2026-08-14 — re-seed roadweaver.json (water-crossing road fix)
Lesson: user reported roads paving through ocean/water (RoadWeaver issue #68 — water in land-tagged biomes treated as land; plus whitelist forced roads to ocean structures structory:boat + dragonsurvival:*_sea, and predictRadiusChunks 1024 connected structures 16km apart). Seeding needed --ignore-existing workaround: remove the instance copy first.
Fix: bumped waterDepthWeight 80->200, nearWaterCost 80->160, biomeWeight 2->4; blacklisted structory:boat + 3 dragonsurvival sea structures; predictRadiusChunks 1024->256.

### 2026-08-15 — source-level patching (build a mod JAR from source)
Lesson: config and jar-metadata replacement (mc-mod-patch) can't fix a bug in compiled Java logic — RoadWeaver paved roads through elevated water (issue #68) because water detection was sea-level-relative in the placement fallback and accurate terrain `waterDepth()`. No roadweaver.json setting could express the fix.
Fix: added `modules/nixos/minecraft-server/modpacks/build-mod-source.nix` (fixed-output derivation: builds `:neoforge:build` with the mod's own gradle wrapper and `pkgs.jdk21`, copies the playable jar to `$out`); per-mod `source-patches/<mod>/default.nix` (pinned `fetchFromGitHub` + git-format patch + `outputHash`); wired into `patches.nix` as a second mechanism passed to both consumers. New `mc-mod-source-patch` skill documents the workflow.
