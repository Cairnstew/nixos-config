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
- **Patch tooling** (datapacks via Paxi):
  - `packwiz-datapack-add` — add a local datapack to `config/paxi/datapacks/`,
    validating pack.mcmeta pack_format against the pack's MC version.
  - `packwiz-datapack-remove` — remove one.
- **Version / QA tooling**:
  - `packwiz-mod-pin` — pin/unpin a mod (pinned = never auto-updated).
  - `packwiz-inspect-mod` — Modrinth API: side, deps, the version for the pack's
    loader+MC; `--jar` lists the config files the mod ships.
  - `packwiz-update-safe` — `update --all` → checksums → verify → git add, one shot.
- `mc-modpack` command — orchestrated workflow for a requested modpack change.
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

### Patches via Paxi datapacks

`config/paxi/datapacks/` is loaded into every world by Paxi (server-side too).
A custom datapack is a zip (or dir) with a `pack.mcmeta` whose `pack_format`
must match the pack's MC version — **1.21.1 = 48**. Remember the 1.21.1 folder
renames when writing recipe/loot patches: `loot_tables` → `loot_table`,
`tags/items` → `tags/item`, `functions` → `function`. KubeJS (`kubejs/`) and
CraftTweaker (`scripts/`) are the script-based patch alternative.

## Gotchas

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
