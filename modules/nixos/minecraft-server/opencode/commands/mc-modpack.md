---
description: Work on a packwiz modpack — add/remove/update mods, convert CurseForge mods, ship default player configs, add Paxi datapack patches, regenerate checksums, verify, and report. $ARGUMENTS describes what to do.
---

You are working on the packwiz modpack(s) in this repo
(`modules/nixos/minecraft-server/modpacks/<name>/`). Load the `mc-modpack`
skill first — it documents the workflow, the packwiz CLI, checksum
generation, the CurseForge-conversion gotchas, and the config/datapack tools.

Request: $ARGUMENTS

## Procedure

1. **Identify the pack.** If `$ARGUMENTS` names a modpack use it, otherwise pick
   the most relevant one under `modules/nixos/minecraft-server/modpacks/`.
   Confirm `pack.toml` exists (MC version + loader) and read it.
2. **Baseline** — run `mc-pack-status` on the pack so you know the starting
   state (mod count, index sync, checksums coverage, CurseForge-mode mods,
   internal files, datapack pack_format).
3. **Make the change** with the `packwiz` tool or the config/patch tools, e.g.:
   - `modrinth add <mod>` to add a mod (dependencies auto-added).
   - `remove <file>.pw.toml` to drop one (list first to get exact filenames).
   - `update --all` / `refresh` to bump/refresh.
   - For a CurseForge-only mod: `curseforge add --addon-id <id>` works for
     packwiz, but it has **no download URL** and will break the Nix build.
     Convert it: prefer `modrinth add <slug>` if a Modrinth version exists;
     otherwise `url add <direct-url>` using the CF CDN URL pattern
     `https://edge.forgecdn.net/files/<fileid//1000>/<fileid%1000>/<filename>`
     (get `file-id` + `filename` from the mod's `[update.curseforge]` /
     `[download]` metadata), then remove the old `.pw.toml`.
   - **Default player configs:** use `packwiz-config-add` to write a file under
     `config/<mod>/<file>` (the pack's `config/` dir). Before writing, use
     `packwiz-config-diff` to see what the mod's stock default is, and decide
     whether to set `preserve` (player edits win, but they never receive later
     improvements) or not (overwritten every install).
   - **Patches:** use `packwiz-datapack-add` to add a local datapack to
     `config/paxi/datapacks/` (validates pack_format against MC 1.21.1 = 48).
     `packwiz-datapack-remove` to drop one. KubeJS (`kubejs/`) and CraftTweaker
     (`scripts/`) are the script-based patch alternative.
   - `packwiz-inspect-mod` to check a mod's side/deps/config-files before adding.
   - `packwiz-mod-pin` to freeze a version that a config or datapack depends on.
4. **Regenerate checksums** with the `packwiz-checksums` tool (required after
   any mod change; NOT needed for config/datapack edits).
5. **Verify** — re-run `mc-pack-status`; it must end `READY for Nix build`
   (index in sync, checksums match, zero CurseForge-mode mods, no duplicates,
   all internal files indexed, datapack pack_formats valid). If a mod still has
   no URL, convert it (step 3) and re-run.
6. **Stage the files** — `git add modules/nixos/minecraft-server/modpacks/<name>`
   (git flakes only see tracked files; without this the flake's checksum app
   and server build won't see the new pack).
7. **Report** a short summary: pack, mods added/removed/updated, config files
   shipped (and preserve state), datapacks added, any CurseForge conversions
   (with URLs), checksum status, and a final `mc-pack-status` line.

## Rules

- Do not fabricate packwiz output — if a command fails, show the error and
  diagnose rather than proceeding.
- Never edit `checksums.json` by hand; always regenerate it.
- Never skip the `git add` step or commit unless asked.
- If `$ARGUMENTS` is just "verify", run steps 2, 5 and 7 only.
