---
name: mc-mod-source-patch
description: Use when a mod in a packwiz modpack in this repo needs a SOURCE-level patch — a bug in compiled Java logic that no config file, datapack, or jar-metadata replacement (mc-mod-patch) can fix — because the mod has to be rebuilt from source. Covers writing a source-patches/<mod>/ module (fetchFromGitHub + a git-format unified diff + FOD outputHash), registering it in patches.nix as a buildModSource entry, and verifying the patched jar ships to both client and server.
---

# Mod Source Patches (build a JAR from source)

Some mod bugs live in **compiled Java logic** — e.g. RoadWeaver's water
detection (`PathSpanExtractor`, `PathPostProcessor`,
`AccurateTerrainRegion`/`AdaptiveCorridorTerrainField.waterDepth()`) — that no
config file, Paxi datapack, KubeJS script, or jar-metadata replacement can
influence. Fix it by **building the whole mod from source** at Nix build time
with a source-level patch, and ship the patched jar exactly like any other mod.

The pack's `.pw.toml` / `index.toml` / `checksums.json` stay byte-identical:
the pack remains a pure list of upstream mods, and the patch re-applies after
every `packwiz update`.

## When to use source-patch vs the other fixes

| Problem | Fix |
|---|---|
| Runtime setting (weights, ranges, blacklists) | `mc-mod-config-set` config / `roadweaver.json` |
| Recipe/loot/structure tweak | Paxi datapack (`packwiz-datapack-add`) |
| Wrong embedded metadata (`versionRange`, deps) | `mc-mod-patch` (`patch-jar.nix` + `patches/<mod>.py`) |
| **Bug in compiled Java logic** (water/terrain/behaviour) | **this skill** (`buildModSource`) |

Source-patching is the heaviest tool: a full Gradle build per mod. Prefer it
only when config and metadata replacement genuinely cannot express the fix.

## How the infra works

- `build-mod-source.nix`
  (`modules/nixos/minecraft-server/modpacks/build-mod-source.nix`) — shared
  helper `buildModSource { name, src, patches, buildCmd?, outputHash }`. A
  **fixed-output derivation (FOD)**: `outputHashMode = "flat"`, so Gradle is
  allowed network (Maven repos, the MC toolchain, and the mod's own gradle
  wrapper distribution) while the output is still pinned and trusted.
  - Uses the mod's own `./gradlew` wrapper (`:neoforge:build` by default):
    nixpkgs' gradle may be rejected by the mod's Loom plugin (RoadWeaver pins
    gradle 8.8, nixpkgs ships 8.14.x). The wrapper downloads its own distro.
  - Builds with `pkgs.jdk21` (`JAVA_HOME`, `HOME=$TMPDIR` for Gradle).
  - Default `buildCmd` builds `:neoforge:build`, picks the first playable jar
    from `neoforge/build/libs/` (excluding `sources`/`dev-shadow`/`dev.jar`),
    and copies it to `$out`. Override `buildCmd` only if the mod's project
    layout differs.
- `<pack>/source-patches/<mod>/default.nix` — per-mod module: calls
  `buildModSource` with the pinned `fetchFromGitHub` src, the patch file(s), and
  the computed `outputHash`. Mirrors how a Nix package patch is structured.
- `<pack>/source-patches/<mod>/<patch>.patch` — git-format unified diff
  (`git diff` with `a/`/`b/` prefixes, paths relative to the repo root), applied
  with `patch -p1` by `buildModSource` (`patches = [ ... ]`).
- `<pack>/patches.nix` — now has **two mechanisms**, both mapped by the
  `"mods/<checksums-key-stem>.jar"` key and both imported by the client
  (`modules/flake-parts/packwiz.nix` `mkClientInstance`) and the server
  (`modules/nixos/minecraft-server/config.nix` `packwizSymlinks`):
  ```nix
  { pkgs, mods, patchJar, buildModSource }:
  {
    "mods/roadweaver.jar" = import ./source-patches/roadweaver {
      inherit buildModSource fetchFromGitHub lib;
    };
  }
  ```
  Consumers pass `patchJar` / `buildModSource` **in** (not imported via
  `../build-mod-source.nix`) because the server's packwiz dir is store-copied —
  a relative import would resolve to `/nix/store/...` and fail. See the comment
  block in `patches.nix`.
- `.packwizignore` must exclude `source-patches/` (and `patches.nix`,
  `patches/`, `checksums.json`) so packwiz doesn't index them.

## Tools

- `git` + the mod's GitHub — read the source and generate the diff. Clone the
  pinned rev, branch off the mod's release branch (e.g. RoadWeaver `1.21.1-Architectury`).
- `nix build --impure .#minecraft-modpack-<pack> --print-out-paths` — build the
  client content. The first run reports the FOD hash mismatch with
  `got: sha256-...`; paste that into `outputHash`. (FODs need `--impure` so the
  fixed-output derivation isn't rejected before it runs.)
- `mc-run <pack> monitor=boot` / `mc-prism-log <pack>` — confirm the patched jar
  loads and behaves.
- Jar inspection (unzip) — verify the patched classes are in the built jar and
  structurally identical to upstream everywhere except the changed files.

## Workflow: source-patch a mod

1. **Diagnose the bug** from the game/`mc-prism-log` or the mod's issue tracker.
   Confirm it's in compiled logic (not config/metadata). Note the exact mod
   version and commit that the pack pins.
2. **Read the pinned source.** `fetchFromGitHub` rev must match the version the
   pack ships (RoadWeaver 2.3.1-1.21.1 → rev `331d4ded…`, the commit its
   `2.3.1-1.21.1-hotfix` jar was built from). Clone and branch it locally; diff
   against the branch, not `master`.
3. **Write the patch.** Edit the source, `git add` the changed files, and
   `git diff HEAD~1 HEAD > elevated-water.patch` from a throwaway repo (or
   `git diff` in the worktree). The diff needs `a/`/`b/` prefixes — `patch -p1`
   strips one leading component.
4. **Write `source-patches/<mod>/default.nix`.** `fetchFromGitHub` (rev + hash),
   `patches = [ ./<patch>.patch ]`, `name = "<mod>-<version>-<fix>.jar"`,
   and a placeholder/known `outputHash`. Comment what the patch fixes and cite
   the upstream issue.
5. **Register in `patches.nix`** under the `"mods/<checksums-key>.jar"` key
   (the pw.toml stem + `.jar`, matching `mkModLinks` output), passing
   `buildModSource`, `fetchFromGitHub`, `lib`.
6. **Stage it** — `git add` the pack dir (flakes only snapshot tracked files).
7. **Compute `outputHash`:**
   - `nix build --impure .#minecraft-modpack-<pack> --print-out-paths` with a
     bogus/placeholder hash → error prints `got: sha256-<…>`.
   - Paste the real hash into `default.nix`, rebuild to confirm it's cached and
     the build succeeds.
8. **Verify the built jar:**
   - Resolve the symlink under `<store>/…/.minecraft/mods/<name>.jar` and
     confirm the patched `.class` files are present and changed (compare
     byte-sizes/hashes against the upstream jar).
   - Check structural equality with upstream elsewhere: same mods.toml version,
     same mixins.json, same `META-INF/jarjar/*`, comparable class lists (only
     the files you patched + expected dead-code/lazily-generated files differ).
   - `mc-run <pack> monitor=boot` — the mod initialises with the new logic.
   - Server side: `nixos-rebuild switch` on the host (server symlinks the same
     patched jars) and restart the server unit.
9. **Report:** mod, the bug (cite the upstream issue), the files changed, the
   patch + `source-patches/<mod>/default.nix` + patches.nix key, and
   build/launch verification.

## Patch conventions

- Fix in the **minimal set of files** and keep the logic close to what the
  mod already does elsewhere — prefer reusing an existing correct rule
  (e.g. RoadWeaver's accurate sampler already tested `oceanFloor < worldSurface`;
  the patch applied that height-based rule to the other water checks).
- Remove now-unused imports/variables (`isWaterLike` import,
  `int sea` param) or the build fails or the patch becomes confusing.
- The patch must **compile** — that's the fail-loud guarantee for a source
  patch (a stale/misapplied patch fails the Gradle build instead of silently
  shipping an unpatched jar). `build-mod-source.nix` also exits 1 if no jar is
  produced.
- Keep `buildCmd` default unless the mod's project layout is unusual.

## Gotchas

- **rev must match the pinned version.** Fetching `master` builds a different
  jar than the pack ships and the checksums pin. Use the exact commit the
  pack's `2.3.1-1.21.1` jar was built from.
- **FODs need `--impure`.** Plain `nix build` (pure eval) rejects a fixed-output
  derivation whose output is supposed to be produced with network access.
- **`outputHash` changes whenever the source patch or src changes.** Recompute
  via the "got:" hash after any patch edit.
- **Use the wrapper.** Don't force nixpkgs' gradle — the mod's Loom plugin can
  reject it. The wrapper downloading its distro inside the FOD is fine.
- **Both sides get it.** Client and server import the same `patches.nix`; don't
  hand-copy a jar into the Prism instance or a store path.
- The server's packwiz dir is store-copied, so `buildModSource`/`patchJar` must
  be **passed in** by consumers (via `inputs.self`), not imported relatively.
- The built jar should be structurally identical to upstream except the patched
  files — flag any unexpected class differences during verification.

## Example (from this repo)

RoadWeaver 2.3.1-1.21.1 paved roads through elevated water (upstream issue
[#68](https://github.com/shiroha-233/RoadWeaver/issues/68)): water detection in
the placement fallbacks and accurate terrain `waterDepth()` was
sea-level-relative, so water above sea level got `waterDepth = 0` → never
bridged. `source-patches/roadweaver/elevated-water.patch` (4 Java files,
git-format diff) makes every check height-based (`waterColumn = oceanFloor <
surfaceY`; `waterDepth = surfaceY - oceanFloor`), reusing the correct rule the
accurate sampler already had. Registered in `patches.nix` as
`"mods/roadweaver.jar"` via `import ./source-patches/roadweaver { … }`.
`nix build --impure .#minecraft-modpack-testModpack` produced
`roadweaver-2.3.1-elevated-water-patched.jar`; the client symlinks it under
`.minecraft/mods/` and the server under the pack's `mods/`.
