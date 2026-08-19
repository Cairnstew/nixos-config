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
├── shaderpacks/*.pw.toml  # client-side shaderpacks (side=client, fetched as FODs)
└── config/            # internal files copied to players: default configs, Paxi datapacks
```

### Shaderpacks (client-side)

Shaderpacks live in `shaderpacks/*.pw.toml` with `side = "client"`. They are
**indexed by packwiz but never counted as mods** — mc-pack-status compares only
`mods/*.pw.toml` for the index-sync check, so shaderpacks appearing in
`index.toml` are expected and not a mismatch.

- **Add**: `packwiz modrinth add <slug>` inside the pack directory places the
  shaderpack at `shaderpacks/<slug>.pw.toml`.
- **Fetch**: `packwiz.nix` fetches each shaderpack via `shaderpackFetch`
  (fetchurl FOD, flat output) and symlinks the zip into `.minecraft/shaderpacks/`
  in the client instance.
- **Instance sync**: `packwiz-instance-sync.py` seeds
  `.minecraft/shaderpacks/` once on install; subsequent syncs leave it alone.
- **Server**: the server never sees shaderpacks — `packSubdirs` and side
  filtering exclude `shaderpacks/` from the server package.

> Example: `DragonTech/shaderpacks/` contains complementary-reimagined,
> complementary-unbound, bsl-shaders, bliss-shader — all `side = "client"`.

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
  - `mc-server` — manage a **dedicated server** defined in
    `modules/nixos/minecraft-server/servers/`. Actions: `status` (state,
    players, uptime, boot progress), `start` / `stop` / `restart`, `boot`
    (start the unit and wait for the `Done (Ns)!` line, diagnosing crashes),
    `perf` (live memory/CPU from the systemd cgroup + TPS/overload/players from
    the log — no monitoring mod required), `list` (configured servers). Uses the
    module's dashboard management API on loopback when reachable, else
    systemctl. Pass `modpack=<name>` to resolve the server that a pack is wired
    to. **This is the primary tool for the server-side workflow** — use it after
    any pack change to confirm the server still boots, and to diagnose a boot
    crash. For performance, load the `mc-server-monitor` skill
    (`mc-server <name> perf` + how to tune the `hardware` option).
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

> **Gotcha — checksums before `git add` silently succeeds without the new mod.**
> If you run `packwiz-checksums` before step 4, the flake's checksum app runs
> inside a `nix run` whose context only sees **git-tracked** files, so it will
> happily exit 0 while quietly omitting any freshly-added `.pw.toml` files. The
> checksum count stays one short of the on-disk mod count and the mismatch only
> surfaces later via `mc-pack-status` (which compares `checksums.json` coverage
> against `index.toml`). Always run checksums AFTER `git add`, and treat
> `mc-pack-status` as the backstop that catches this.

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

### Server-side workflow (use `mc-server`)

1. Wire the pack (`servers.<name>.packwiz = ../modpacks/<pack>`) and enable it
   (`my.services.minecraftServer.servers.<name>.enable = true` in a host config).
2. `mc-server list` → confirm the server is registered.
3. `mc-server <name> boot` → start and wait for `Done (Ns)!`. **A large pack's
   first boot is SLOW** — 200+ mods can take 10+ minutes (DragonTech: ~675s on a
   fresh world before tuning; after RoadWeaver preload-radius tuning ~107s).
   Subsequent boots ~85s. The tool waits up to 20 min by default. Do not assume
   the server is wedged just because it's still loading — and if it clears the
   mod-loading phase but then idles at high CPU for a long time on a fresh
   world, suspect RoadWeaver's preload radii (see gotchas) rather than a hang.
4. `mc-server <name> status` → players / uptime / boot progress anytime.
5. After any pack change (add mod, mark a mod side, patch, config edit):
   rebuild the host and re-run `mc-server <name> boot` to confirm it still boots.

### Server-only gotchas (client-first packs hit these on their first server run)

- **The server links ONLY `side = "both"` / `side = "server"` mods.** The module
  filters `side = "client"` mods out of `mods/` (`packwizSymlinks` in
  `config.nix`), because client-only render/GL mods (Sodium, Iris, …) crash a
  headless server (their pre-launch checks need LWJGL). This filtering is
  correct and should not be removed.
- **A mod tagged `side = "both"` that loads client-only classes crashes the
  server at boot.** `mc-pack-status` flags known ones (Sinytra Connector stack,
  FTB Quests Throughput, Wakes Reforged, …). Symptom:
  `Failed to create mod instance. ModID: X` / `Failed to register automatic
  subscribers. ModID: X` / `Attempted to load class net/minecraft/client/...
  for invalid dist DEDICATED_SERVER` (from `journalctl -u
  minecraft-server-<name>` or the server log). Fix: set `side = "client"` in
  the mod's `<pack>/mods/<mod>.pw.toml`, `packwiz refresh`, rebuild. The Prism
  client still gets the mod; only the server drops it.
- **Benign mixin warnings are NOT crashes.** A big pack logs hundreds of
  `@Mixin target ... was not found` / `Error loading class` warnings during
  first boot (client-only mixins, optional-mod references). Ignore them; only
  `Failed to (create mod instance|register automatic subscribers)` and
  `Mod loading has failed` are fatal.
- **The server writes to `config/` and `defaultconfigs/` at boot** (FML
  generates `config/fml.toml`, mods write defaults). `packwizStartPre` seeds
  these as real writable dirs (`rsync --ignore-existing` + `chmod u+w`), NOT
  symlinks into the read-only store. If you see `Read-only file system` or
  `AccessDeniedException: .../config/fml.toml`, that's a regression in
  `packwizStartPre` — fix it there, don't work around it in the pack.
- **The web console user needs `wheel`.** `security.sudo.extraRules` grants the
  console/dashboard user NOPASSWD `systemctl ... minecraft-server-*`, but the
  sudo wrapper itself is setuid `root:wheel` — the user must be in `wheel`
  (`extraGroups = [ "wheel" ]`) or every `sudo` call returns `Permission
  denied`. This silently breaks the web-console `.start`/`.stop` dot-commands
  AND the dashboard toggle buttons.
- **The dashboard has a Minecraft section** (status + Start/Stop/Restart) backed
  by the `minecraft-dashboard-api` service, registered by the minecraft-server
  module via `my.services.proxy.dashboard.minecraft`. No manual wiring needed.
- **Cap server resources via the per-server `hardware` option**, not by editing
  the JVM string alone. The unit gets systemd cgroup limits
  (`memoryHigh`/`memoryMax`/`memorySwapMax`/`cpuQuota`/`nice`/`ioWeight`)
  wired into `systemd.services.minecraft-server-<name>.serviceConfig`. Size the
  JVM heap for the box and keep ≥4G headroom for the OS + other services; set
  `memoryMax` well above steady-state RSS or the unit gets OOM-killed. Monitor
  with `mc-server <name> perf` (cgroup memory/CPU + log TPS/overload), and load
  the `mc-server-monitor` skill for the full workflow.
- **A post-"Done" stall on a fresh world can be RoadWeaver's preload, not a
  hang.** RoadWeaver's OpenCL coarse-sampling **falls back to CPU** when base
  c2me's density-function nodes are present (benign log lines: `OpenCL 粗采样暂不
  支持主世界，回退到 CPU: unsupported density node: com.ishland.c2me.opts.df...`).
  With the CPU fallback, the `config/roadweaver/roadweaver.json` preload radii
  are the lever: `predictRadiusChunks 256` + plan radii `128` spun ~4 CPU cores
  for hours after boot on DragonTech (looked like a hang). Tune them down for
  fresh-world boots (DragonTech uses 32/16/16, `initialGenerationThreads 6`).
- **Pack config changes do NOT reach an already-booted server's live config.**
  `packwizStartPre` seeds `config/` and `defaultconfigs/` with
  `rsync --ignore-existing` (config.nix:182) — a pack-side config edit only
  lands on a *fresh* data dir. To change a live server's config, edit the file
  directly in the data dir (`/mnt/data/minecraft/<server>/config/...`) and
  restart, OR wipe/rename the config dir and let the next start re-seed.
- **GPU worldgen is dormant, not wired.** c2me-ocl was removed (NVIDIA 595.80
  OpenCL compiler hangs on `clBuildProgram`); the OpenCL/device-access wiring
  (`PrivateDevices=false` + `DeviceAllow`, `ocl-icd`, LD_LIBRARY_PATH, the
  `-Dorg.lwjgl.opencl.libname` jvmOpt) is left dormant and harmless. Don't
  re-add c2me-ocl or re-investigate OpenCL issues without loading the
  `mc-gpu-worldgen` skill first.

## RUN LOG

### 2026-08-14
2026-08-14 — re-seed roadweaver.json (water-crossing road fix)
Lesson: user reported roads paving through ocean/water (RoadWeaver issue #68 — water in land-tagged biomes treated as land; plus whitelist forced roads to ocean structures structory:boat + dragonsurvival:*_sea, and predictRadiusChunks 1024 connected structures 16km apart). Seeding needed --ignore-existing workaround: remove the instance copy first.
Fix: bumped waterDepthWeight 80->200, nearWaterCost 80->160, biomeWeight 2->4; blacklisted structory:boat + 3 dragonsurvival sea structures; predictRadiusChunks 1024->256.

### 2026-08-15 — source-level patching (build a mod JAR from source)
Lesson: config and jar-metadata replacement (mc-mod-patch) can't fix a bug in compiled Java logic — RoadWeaver paved roads through elevated water (issue #68) because water detection was sea-level-relative in the placement fallback and accurate terrain `waterDepth()`. No roadweaver.json setting could express the fix.
Fix: added `modules/nixos/minecraft-server/modpacks/build-mod-source.nix` (fixed-output derivation: builds `:neoforge:build` with the mod's own gradle wrapper and `pkgs.jdk21`, copies the playable jar to `$out`); per-mod `source-patches/<mod>/default.nix` (pinned `fetchFromGitHub` + git-format patch + `outputHash`); wired into `patches.nix` as a second mechanism passed to both consumers. New `mc-mod-source-patch` skill documents the workflow.

### 2026-08-15 — first dedicated-server run: client-first packs crash a headless server
Lesson: the DragonTech pack (formerly testModpack) ran fine in Prism but boot-looped on the dedicated server. Three distinct server-only failure modes, in order: (1) client-only render/GL mods symlinked into `mods/` crash with `NoClassDefFoundError: org/lwjgl/Version` — fixed by filtering `side = "client"` mods server-side (packwizSymlinks); (2) mods tagged `side = "both"` that load client-only classes (Sinytra Connector stack, FTB Quests Throughput, Wakes Reforged) crash mid-mod-load with `Failed to create mod instance. ModID: X` / `... for invalid dist DEDICATED_SERVER` — fixed by marking them `side = "client"`; (3) `config/` was symlinked into the read-only store so FML couldn't write `config/fml.toml` (`Read-only file system`) — fixed by seeding `config/`/`defaultconfigs/` as writable dirs in `packwizStartPre`. Also discovered the smoke test never passed for neoforge (it searched for a top-level jar, but neoforge's server jar lives under `libraries/`), and the web console user needed `wheel` to exec the sudo wrapper.
Fix: added the `mc-server` tool (status/start/stop/restart/boot with crash diagnosis), a `side` split + client-crash-risk check to `mc-pack-status`, a longer server boot default timeout in `mc-run`, fixed the smoke-test jar search, and documented the server-side workflow in this skill.

### 2026-08-15 — server performance monitoring + resource caps
Lesson: the dedicated server (DragonTech) had no memory/CPU limits (`MemoryMax = infinity`) on a tight host (15G RAM, 5G swap used, server RSS ~5.5G vs `-Xmx6G`). First boot showed `Can't keep up! ... 313 ticks behind` during worldgen — transient, not a fault. nix-minecraft forwards no per-server systemd fields, so caps had to go through the wrapper module.
Fix: new per-server `hardware` submodule (`memoryHigh`/`memoryMax`/`memorySwapMax`/`cpuQuota`/`nice`/`ioWeight`) wired into `systemd.services.minecraft-server-<name>.serviceConfig`; tuned the dragentech server to `-Xmx5G -Xms3G` + `memoryHigh 7G / memoryMax 10G / memorySwapMax 2G / nice 5`. Added `mc-server <name> perf` (cgroup memory/CPU + log TPS/overload/players) and the `mc-server-monitor` skill documenting monitoring + how to size caps.

### 2026-08-16 — GPU worldgen saga; c2me-ocl removed; RoadWeaver preload tuning
Lesson: tried GPU-accelerated worldgen (c2me-ocl) on DragonTech. Two hard failures after the wiring was made: (1) `CL_PLATFORM_NOT_FOUND_KHR` / -1001 because nix-minecraft hardens units with `PrivateDevices=true` + `DevicePolicy=closed`, hiding `/dev/nvidia*` and `/dev/dri/*` from the unit — fixed by `PrivateDevices=false` + `DeviceAllow` for the NVIDIA/DRM nodes (`mkHardwareServiceConfig` in config.nix); (2) with the GPU reachable, the NVIDIA 595.80 OpenCL compiler hangs indefinitely (`clBuildProgram` JNI, ~110ms CPU progress over 35+ min) on c2me's generated noise kernel — a vendor driver bug, not config-fixable. `-XX:+UseCompactObjectHeaders` tried while chasing it broke JNI/FFI — removed. Also: RoadWeaver's OpenCL coarse sampling falls back to CPU (benign log lines) and its huge default preload radii (256/128) spun 4 cores for hours after "Done" on a fresh world, looking like a hang.
Fix: removed c2me-ocl from the pack, re-added Noisium, kept the OpenCL/device-access wiring dormant for a retry, tuned RoadWeaver preload radii (predict 256->32, plan 128->16, threads 12->6) → first boot `Done (107.467s)`, 0 restarts. Added the `mc-gpu-worldgen` skill documenting the saga + retry checklist, and this RUN LOG + the preload-stall / rsync live-config gotchas.

