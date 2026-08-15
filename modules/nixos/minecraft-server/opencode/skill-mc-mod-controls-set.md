---
name: mc-mod-controls-set
description: Use when asked to set, change, or ship default hotkeys/controls for a whole packwiz modpack in this repo — defining what controls players start with by writing the pack's options.txt at the PACK ROOT (game root on install, NOT under config/), rebinding a specific key, seeding from a tuned generated options.txt, or deciding the preserve flag. The write step that pairs with the mc-mod-controls review skill.
---

# Set Default Controls (packwiz)

Ship the modpack's **default hotkeys/controls** to players by writing
`options.txt` into the **packwiz pack directory** — the version-controlled
source of truth under `modules/nixos/minecraft-server/modpacks/<name>/` — so
every install (Nix client build, Prism reinstall) reproduces it.

**The target is the pack ROOT, and only the pack directory.** Minecraft reads
controls from `options.txt` at the game root, and packwiz maps a pack-root file
1:1 to the game root on install. Never write to a running instance's
`.minecraft/options.txt`, a `/nix/store/…` build, or `/run/current-system/…` —
those are throwaway artifacts; your change vanishes on the next rebuild.

## How controls get to players

- Every keybinding (vanilla + mods) is a `key_<id>:<code>` line in
  `options.txt` at the game root. Ship a pack-root `options.txt` to override
  the stock controls for every player.
- packwiz installers place a pack-root `options.txt` at the game root
  (verified against packwiz-installer's path mapping — internal files keep
  their pack-relative path in the game folder).
- The repo's Nix builds ship it too: `modules/flake-parts/packwiz.nix`
  `mkClientInstance` symlinks `<pack>/options.txt` → `.minecraft/options.txt`,
  `packwiz-instance-sync.py` seeds it only-when-absent, and the server's
  `packwizStartPre` (`modules/nixos/minecraft-server/config.nix`) symlinks it
  into the server data dir. One write, both sides.
- **Keybind codes**: `key.keyboard.<key>` (letters, `space`, `left.control`,
  `f5`, `keypad.1`, …), `key.mouse.left|right|middle`, plus an optional
  modifier suffix like `:CONTROL` / `:SHIFT`. `key.keyboard.unknown` = unbound.

## Tools

- `packwiz-controls-set <pack> keys=<'key_<id>=<code> ...'> [from=<path>]
  [preserve=true]` — **the write primitive**: writes the pack's `options.txt`
  at the pack root, runs `packwiz refresh` (re-hashes into index.toml), and
  with `preserve=true` marks the index entry.
  - `keys` — space-separated `key_<id>=<code>` overrides; sets/updates just
    those keybindings and keeps the rest of the file (if the pack already
    ships one).
  - `from=<abs-path>` — seed the file from a generated/tuned `options.txt`
    (e.g. a configured instance's) to copy non-key settings too; `keys` still
    apply on top.
- `packwiz-controls <pack> [mod=<slug>]` — **review first**: what the pack
  currently ships / what the defaults are, ids to use, conflicts to fix. Full
  workflow in the `mc-mod-controls` skill.
- `mc-run <pack> monitor=boot` — launch once to produce a generated
  `options.txt` to use as the `from=` seed, or to verify after setting.
- `packwiz-config-list <pack>` — confirm `options.txt` is indexed + its
  preserve state.

## Workflow: set the pack's default controls

1. **Review the current state** — `packwiz-controls <pack>`. Know what the pack
   ships today (if anything) and what ids exist for the keys you want to
   change.
2. **Get the exact id + code.** The id is the `key_<id>` part (e.g.
   `iris.keybind.reload`, `key.ae2.wireless_terminal`, `key_key.sneak`). Copy
   it exactly from the review output — never invent an id.
3. **Decide the change:**
   - **Rebind one or a few keys** → `packwiz-controls-set <pack> keys='key_<id>=<code> ...'`.
   - **Ship a fully-tuned file** (graphics + sound + keys) → seed with
     `from=<path-to-generated-options.txt>` after tuning a launch, optionally
     adding `keys=` overrides on top.
   - If the pack already ships an `options.txt`, `keys=` edits merge into it;
     non-key lines are preserved.
4. **Decide `preserve` explicitly and record why:**
   - `preserve=true` — installed only if the player has no `options.txt` yet;
     players who already ran the pack keep their controls forever (and never
     receive later improvements). Good for not clobbering player remaps.
   - no flag (default) — the pack's file is enforced on every install.
     **Recommended for keybinds a datapack/KubeJS/script depends on**, or when
     you explicitly want to push a new default to existing players.
5. **Verify** — `packwiz-controls <pack>` now shows the pack-shipped file
   (header `pack ships options.txt (<state>)` and your bindings as the values);
   `packwiz-config-list <pack>` shows `options.txt` indexed.
6. **Reproduce** — `git add modules/nixos/minecraft-server/modpacks/<name>`
   (flakes only see tracked files). No `packwiz-checksums` regen — that's only
   for mod jars.

## Hard rules

- **Target is always the pack root, never a runtime location.** If you catch
  yourself writing to an instance's `.minecraft/options.txt`, a `/nix/store/`
  path, or `/run/current-system`, stop: write `<pack>/options.txt` and rebuild.
- **Always refresh** (`packwiz-controls-set` does it) — the file must be in
  index.toml or it silently never ships.
- **Preserve is a real decision** — set it explicitly and report it.
- **Never hand-edit `checksums.json`**; never run `packwiz-checksums` for a
  controls-only change.
- **Don't guess ids or codes.** Get the id from `packwiz-controls`; get codes
  right (`key.keyboard.left.control`, `:SHIFT` suffix, etc.) — a wrong code is
  a silently-broken binding.
- For a large tuned file prefer `from=` (a real file) over a giant `keys=`
  string.

## Gotchas

- **`options.txt` belongs at the pack ROOT, not under `config/`.** A `config/`
  copy would land in `config/options.txt` at runtime — the game ignores it.
- **Fresh players vs existing players:** with `preserve`, existing players keep
  their controls and never get your new defaults; without it, every reinstall
  overwrites their remaps. Choose per the goal and say which you picked.
- Conflicts (two actions on one key) still exist after shipping a default if
  you only rebind one of them — rebind both sides of a conflict you mean to
  resolve.
- `packwiz-controls-set` seeds from `from=` only if that path exists; a
  mistyped path falls back to the pack's existing file (or an empty one) — pass
  a real path and verify the resulting file.
- The server symlinks the same `<pack>/options.txt` into the data dir; pick it
  up with `nixos-rebuild switch` on the host, then restart the server unit.

## Example

```
user: make the pack's default sneak key X and iris reload L, keep player remaps.

1. packwiz-controls testModpack  → pack ships nothing; ids key_key.sneak,
   iris.keybind.reload confirmed; R also bound to epicfight.switch_mode (conflict)
2. packwiz-controls-set testModpack \
     keys='key_key.sneak=key.keyboard.x iris.keybind.reload=key.keyboard.l' \
     preserve=true
3. packwiz-controls testModpack → header "pack ships options.txt (preserve)",
   key.sneak = X, iris.keybind.reload = L
4. git add modules/nixos/minecraft-server/modpacks/testModpack
   report: options.txt written at pack root, preserve=on (existing players keep
   their remaps; fresh installs get the new defaults), index refreshed, no
   checksums regen needed.
```
