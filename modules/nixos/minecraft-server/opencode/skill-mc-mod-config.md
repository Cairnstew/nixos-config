---
name: mc-mod-config
description: Use when asked to review or retrieve the configuration of a specific mod in a packwiz modpack in this repo — listing a mod's shipped default config files, getting/printing a config file's contents, checking whether the pack overrides a mod's config, or comparing a pack override against the mod's stock defaults before shipping a default player config.
---

# Mod Config Review (packwiz)

Consistently review or get the config of **one specific mod** in a packwiz
modpack under `modules/nixos/minecraft-server/modpacks/<name>/`. Uses the
pack's **pinned** jars (from `checksums.json`) so what you review is exactly
what players get — never a different version.

For broad pack work (adding/removing/updating mods, datapacks, deploying)
load the `mc-modpack` skill instead. This skill is the "review the config"
step; `packwiz-config-add` from that skill is the "write the config" step.

## Tools

- `packwiz-config-show <pack> <mod> [config/<path>] [contents=true]` — **the
  retrieval primitive.** Resolves the mod to its pinned jar, lists every
  `config/` file it bundles (size + override status), or prints a chosen
  file's contents. `contents=true` dumps every shipped file.
- `packwiz-config-diff <pack> <rel-path>` — unified diff of a **pack override**
  (`config/<rel-path>`) vs the owning mod's stock file from the same pinned jar.
- `packwiz-config-list <pack>` — inventory of everything the pack ships in
  `config/` (with `preserve` state). Context for which overrides already exist.
- `packwiz-inspect-mod <pack> <slug> [jar=true]` — Modrinth metadata (side,
  deps, version). **Uses the latest Modrinth release, not the pinned jar** —
  OK for context/pre-add decisions, never for quoting what ships.

## Reading `packwiz-config-show` output

```
foo → foo.pw.toml  (foo-1.0.jar)                      # resolved identity + pinned jar
  ships 2 config file(s):
    config/foo/foo.toml  (23 B) (no pack override)    # default is what players get
    config/foo/extra.toml (15 B) (pack override: identical)
    config/foo/big.toml  (9 KB) (pack override: DIFFERS — review with packwiz-config-diff)
```

- `(no pack override)` — players get the jar's stock file. The printed content
  IS the default.
- `(pack override: identical)` — pack ships a copy that matches stock.
- `(pack override: DIFFERS …)` — pack ships a different copy; run
  `packwiz-config-diff` to review exactly what changed.
- `ships no config/ files` — the mod generates its config at first launch
  (common for modern NeoForge mods). There is no stock file to quote; report
  that, and if you need the real defaults, check the generated config in a
  launched instance's `.minecraft/config/` (e.g. via `mc-run` then a read of
  the instance dir).

## Workflow: review the config for mod X in pack P

1. **Resolve + list** — `packwiz-config-show P X`. Accepts a display name,
   slug, or `.pw.toml` filename; ambiguous names error with candidates — then
   pass the exact slug/filename. Record the pinned jar it resolved to.
2. **If it ships configs**, read the listing. For every file you must discuss,
   pull its contents: `packwiz-config-show P X config/<modid>/<file>`.
3. **Review overrides** — for each `(pack override: DIFFERS …)` entry, run
   `packwiz-config-diff P <rel-path>` and summarize the delta (what the pack
   changes vs stock, and why, if the request implies a reason).
4. **Optional context** — `packwiz-inspect-mod P X` for side/deps/version.
   Label it as *latest-version* info, distinct from the pinned jar.
5. **Report** consistently:
   - Resolved mod + pinned jar filename (proves which version was reviewed)
   - Config files it ships (or "ships none — runtime-generated")
   - Override status per file, with diffs for any that differ
   - Anything notable in the contents relevant to the request

## Workflow: get (quote) the config for mod X

- Default state: `packwiz-config-show P X` → if `(no pack override)`, the
  listed content is the player default. Quote it.
- If overridden: quote **the pack's** `config/<modid>/<file>` (what actually
  ships) and note that it differs from stock, using `packwiz-config-diff` to
  show the difference.
- Cap: files print up to 400 lines; if a file is truncated the output says
  `… (N more lines)`. If you need the tail, say so and read it explicitly.

## Accuracy rules

- **Always review from the pinned jar.** `packwiz-config-show`/`-diff` read
  `checksums.json` — the exact URLs packwiz2nix builds. Never describe a mod's
  config from Modrinth's latest release unless the pack pins that version.
- **Never fabricate config content.** If a file isn't shown, fetch it with the
  tool. If the tool errors, report the error and diagnose — do not improvise.
- **Resolve identity before quoting.** If `X` is ambiguous, use the slug the
  tool resolved, not the user's spelling.
- **Override mapping is by path**: jar `config/<a>/<b>` ↔ pack
  `config/<a>/<b>`; the first segment under `config/` is the modid.
- `(no download URL)` from the tool means the mod is CurseForge-mode and has no
  pinned jar yet — convert it first (see the `mc-modpack` skill) or state that
  the config can't be read from a pinned jar.

## Gotchas

- Many mods ship **zero** `config/` files (defaults generated at first run) —
  that's a valid, complete answer; don't go hunting Modrinth for a "stock"
  file that never ships.
- Mods can bundle config at `config/<modid>/…` or directly `config/<file>` —
  the tool lists the real jar paths; trust its listing over assumptions.
- Pinned jar ≠ the version `packwiz-inspect-mod` queries (latest). When a user
  asks "what config does version X ship", verify X == the pinned jar filename.
- `config/` only: resources/resourcespacks/assets shipped inside the jar are
  not config and are out of scope for this skill.

## Example

```
user: what config does sodium-dynamic-lights ship in testModpack, and does the pack change it?

1. packwiz-config-show testModpack sodium-dynamic-lights
   → sodium-dynamic-lights → sodium-dynamic-lights.pw.toml (sodiumdynamiclights-neoforge-1.0.10-1.21.1.jar)
     ships no config/ files
   → report: ships no config; defaults are generated at first launch; the pack
     doesn't override anything for it (no config/ files at all).
```
