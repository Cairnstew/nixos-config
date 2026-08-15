---
name: mc-mod-config-set
description: Use when asked to set or change a mod's default config in a packwiz modpack in this repo — defining what config a mod ships to players by writing the file into the pack's config/ directory reproducibly (NOT into a running instance or an already-built pack), deciding the preserve flag, or updating a previously shipped default. The write step that pairs with the mc-mod-config review skill.
---

# Set a Mod Default Config (packwiz)

Ship a default config for a specific mod by writing it into the **packwiz pack
directory** — the version-controlled source of truth under
`modules/nixos/minecraft-server/modpacks/<name>/` — so every install (Nix
client build, server symlinks, Prism reinstall) reproduces it byte-for-byte.

**The target is always the pack directory.** Never edit a running instance's
`.minecraft/config/`, a `/nix/store/…` build, or `/run/current-system/…` —
those are throwaway artifacts; your change vanishes on the next rebuild and is
not reproducible. Reading from them to obtain content is fine; writing to them
is a bug.

## How packwiz does this (docs)

- **Internal files tutorial:** "Configuration files for your modpack can
  simply be placed in a config folder (in the same place as the mods folder)
  and they'll be copied to the config folder when installing the modpack … Make
  sure you run `packwiz refresh` so that the index is up to date!"
  → `<pack>/config/<rel-path>` maps 1:1 to `<game-dir>/config/<rel-path>` on
  install, and `packwiz refresh` hashes it into `index.toml`.
  https://packwiz.infra.link/tutorials/creating/adding-mods/
- **`index.toml` → `preserve`:** "When this is set to true, the file is not
  overwritten if it already exists, to preserve changes made by a user."
  https://packwiz.infra.link/reference/pack-format/index-toml/

## Tools

- `packwiz-config-add <pack> <relPath> [content | sourceFile] [preserve=true]`
  — the **write primitive**: writes `<pack>/config/<relPath>`, runs
  `packwiz refresh` (re-hashes into index.toml), and with `preserve=true` marks
  the index entry. Multi-line `content` is safe.
- `packwiz-config-show <pack> <mod> config/<path>` — get a mod's stock file
  from its **pinned jar** (baseline for an edit). Full workflow in the
  `mc-mod-config` skill.
- `packwiz-config-list <pack>` — confirm the file is indexed + its preserve
  state.
- `mc-pack-status <pack>` — final "READY for Nix build" verification (all
  internal files indexed).
- `mc-run <pack> monitor=boot` — launch once to generate a runtime-only config
  (source content), then copy it into the pack.

## Workflow: set a mod default config

1. **Pick the file.** Determine where the mod reads its config at runtime:
   usually `config/<modid>/<file>` in the game dir, so the pack path is
   `<pack>/config/<modid>/<file>`.
2. **Get the baseline content:**
   - Mod ships a stock config in its jar → `packwiz-config-show <pack> <mod>
     config/<modid>/<file>` and edit from that (pinned-version accurate).
   - Mod generates configs at runtime (`packwiz-config-show` says "ships no
     config/ files") → run `mc-run <pack> monitor=boot` once, then read the
     generated file from the instance's `.minecraft/config/<file>`. That
     generated file is the only reliable format reference.
   - Updating an existing pack default → read `<pack>/config/<file>` directly.
3. **Decide the desired default.** Make small, deliberate edits to the baseline
   — not a wholesale rewrite. If the change must also apply to a datapack or
   KubeJS script, keep those consistent.
4. **Write it into the pack** with `packwiz-config-add <pack> <relPath>`:
   - `content='<text>'` for inline content (multi-line TOML is fine).
   - `sourceFile=<abs-path>` to copy an existing/generated file.
   - It runs `packwiz refresh` automatically. **Never skip the refresh** — a
     file on disk but missing from index.toml silently never reaches players.
5. **Decide `preserve` explicitly and record why:**
   - `preserve=true` — installed only if the player has no copy yet; their
     edits always win. Good for defaults you don't want clobbered, but existing
     players never receive later improvements to that file.
   - no flag (default) — overwritten on every install; the pack's default is
     guaranteed. Use when a datapack/KubeJS/script depends on the exact content.
6. **Verify** — `packwiz-config-list <pack>` shows the file with its indexed +
   preserve state; `mc-pack-status <pack>` ends "READY for Nix build".
7. **Reproduce** — `git add modules/nixos/minecraft-server/modpacks/<name>`
   (flakes only see tracked files). Config edits need **no**
   `packwiz-checksums` regeneration — that is only for mod jars.

## Hard rules

- **Target is always the pack dir.** If you catch yourself writing to a Prism
  instance `.minecraft/`, a `/nix/store/` path, or `/run/current-system`, stop:
  write to `<pack>/config/` and rebuild.
- **Always refresh** (`packwiz-config-add` does it); the file must be in
  index.toml or it never ships.
- **Preserve is a real decision** — set it explicitly and report it, don't
  leave it implicit.
- **Never hand-edit `checksums.json`**; never run `packwiz-checksums` for a
  config-only change.
- **Don't guess the config format.** If the mod generates configs at runtime,
  generate-then-copy; if it ships one, start from the pinned jar's copy.
- For content with special characters, prefer `sourceFile` when you have a real
  file; `content` is fine for small inline edits.

## Gotchas

- "Ships no config/ files" ≠ no config — it is generated on first launch. Use
  `mc-run` once to produce it, then copy it into the pack.
- `preserve` only affects installs that don't already have the file. To push a
  new default to existing players, deploy a rebuild/reinstall (the file must
  be non-preserve to overwrite).
- A config the server reads is symlinked from the pack's `config/` into the
  server data dir at start — pick it up with `nixos-rebuild switch` on the
  host, then restart the server unit.
- **`packwiz-instance-sync.py` (and `mc-install`) seed `config/` with
  `--ignore-existing`.** A config the mod already generated in the target
  instance (e.g. a runtime-generated `config/<modid>/*.json`) is NOT
  overwritten by your new pack default, and `mc-install`'s diff won't even
  flag it (it only checks internal dirs as present/absent, not per-file
  content). To push a changed default to an existing install: delete the
  stale instance file first, then `mc-install force=true` — otherwise the
  instance keeps the old value and the "install" silently does nothing for
  that file.
- The repo's Nix build ships the pack `config/` into the client
  (`mkClientInstance`) and the server (`packwizSymlinks`) from the same
  directory — that is what makes one write reproducible everywhere.

## Example

```
user: set the testModpack default for the dynamic lights mod to quality = high.

1. packwiz-config-show testModpack sodium-dynamic-lights
   → ships no config/ files (runtime-generated)
2. mc-run testModpack monitor=boot   # generates config in the instance
3. read <instance>/.minecraft/config/sodium-dynamic-lights.properties,
   set quality = high
4. packwiz-config-add testModpack sodium-dynamic-lights/sodium-dynamic-lights.properties \
     sourceFile=<instance generated file>   # no preserve → overwrites each install
5. packwiz-config-list testModpack   → shows "overwrite" state, indexed
6. git add modules/nixos/minecraft-server/modpacks/testModpack
   report: file written to pack config/, preserve=off (default guaranteed),
   index refreshed, no checksums regen needed
```

## RUN LOG

### 2026-08-14 — `--ignore-existing` seeding gotcha
- Lesson: pushed a changed RoadWeaver default (`config/roadweaver/roadweaver.json`
  with an expanded structureWhitelist) into an existing Prism instance; the
  install reported "up to date" and the instance kept its old runtime-generated
  file because `packwiz-instance-sync.py` seeds `config/` with `--ignore-existing`
  and `mc-install`'s diff only checks internal dirs as present/absent.
- Fix: added the gotcha above — delete the stale instance config file first,
  then `mc-install force=true`.
