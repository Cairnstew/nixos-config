# ThunderStore (mods for Steam games)

> Hash-pinned [ThunderStore](https://thunderstore.io) mod packs, installed into the
> Steam game directory that is discovered from your own Steam configuration.
> Metadata lives in git; the bytes are verified at build time.

## What this models

ThunderStore is not one mod manager but a shared index with **351 games**, each
with its own community, its own mod loader and its own install layout. This
module models that rather than hardcoding "BepInEx + Lethal Company":

| ThunderStore concept | Where it lives here |
|---|---|
| Game / community / distribution (Steam, EGS, …) | `game.json` → `game`, `communityMeta`, `model.distributions` |
| Steam appid, `steamFolderName`, `dataFolderName`, `exeNames` | `game.json` → `model` |
| `packageLoader` (13 values) | `lib/loaders.nix` → `byLoader.<loader>` |
| `installRules` (`route` + `trackingMethod` + `defaultFileExtensions`) | `game.json` → `model.installRules`, applied by `lib/route.py` |
| Loader payload rules (what a loader *pack* installs) | `lib/loaders.nix` → `byLoader.<loader>.payload` |
| Loader pack registry (`rootFolder`) | `game.json` → `model.loaderPackageRootFolder` |
| Community `autolistPackageIds` (5 legal values) | `game.json` → `model.autolistPackageIds` |
| Package dependencies (`<ns>-<name>-<version>`) | `checksums.json` → `dependencies` (resolved transitively) |
| Per-destination layouts (`gameRoot`, `dataBinaries`, `releaseDir`) | `lib/loaders.nix` → `destinations`, resolved by `lib/install.sh` |

The ecosystem data itself is **not** vendored. `thunderstore-sync` fetches
ThunderStore's published schema
(`https://thunderstore.io/api/experimental/schema/dev/latest/`) once and freezes
the entry for the pack's game into `game.json`, which is committed. So the model
is auditable against upstream, reproducible, and never fetched during evaluation.

## Pack layout

```
modules/home/thunderstore/packs/<name>/
├── pack.json       # authored: which game, which loader, which mods
├── game.json       # generated + committed: the frozen ecosystem model
└── checksums.json  # generated + committed: url + sha256 per package
```

`pack.json`:

```json
{
  "name": "lethal-company",
  "game": "lethal-company",
  "instance": 0,
  "installLoader": true,
  "loaderPackage": "BepInEx-BepInExPack",
  "loaderVersion": "5.4.2305",
  "mods": {
    "notnotnotswipez-MoreCompany": "1.14.0",
    "x753-Mimics": "2.7.4"
  }
}
```

| Field | Meaning |
|---|---|
| `game` | ecosystem slug = the community (`riskofrain2`, `repo`, `northstar` — not the game title) |
| `instance` | `0` (default), an index, or `"game"` / `"server"` — a game may ship several layouts (Valheim has both) |
| `installLoader` | install the loader pack as part of this pack; defaults to true when the community has an autolist package |
| `loaderPackage` / `loaderVersion` | one loader, pinned once — every mod depends on *some* BepInEx 5.x, and we do not want one per dependency |
| `mods` | `<namespace>-<name>` → exact version (`null` = newest at sync time) |
| `exclude` | packages never installed, even as a dependency |
| `allowConflicts` | allow two packages to write the same path (default: the build fails) |
| `notes` | free text, carried into the manifest |

## Creating a pack

All commands run **from the repo root**, and new files must be `git add`ed first —
a flake only sees git-tracked files.

```sh
mkdir -p modules/home/thunderstore/packs/<name>
$EDITOR modules/home/thunderstore/packs/<name>/pack.json
git add modules/home/thunderstore/packs/<name>/pack.json

# 1. is the game modelled, and how does it install?
nix run .#thunderstore-game-info -- lethal-company

# 2. freeze the ecosystem model → game.json
nix run .#thunderstore-sync -- <name>

# 3. download + pin every mod and its dependencies → checksums.json
nix run .#thunderstore-checksums -- <name>

# 4. prove the pinned bytes build, then look before you leap
nix build .#thunderstore-pack-<name>
nix run .#thunderstore-plan-<name>

# 5. install
nix run .#thunderstore-install-<name>
```

Then enable it on a host:

```nix
home-manager.users.seanc.my.programs.thunderstore = {
  enable = true;
  packs.<name> = {
    enable = true;              # installs on `home-manager switch`
    dryRun = true;              # …or only report, until you are happy
    # gameDir = "/mnt/games/steamapps/common/Lethal Company";  # skip discovery
    # appId = "1966720";                                     # mirror steam config
    # extraFlags = [ "--require-exe" ];
  };
};
```

`appId` exists so a pack can be pointed at a different copy of the game, and so it
can mirror the appid already declared in
`my.programs.steam.games.<name>.appId` (`modules/nixos/steam`) when that is the
number you trust. Left null — the default — the ecosystem's appid is used, which
is the authoritative one.

## How the Steam game directory is found

`lib/install.sh` resolves it at run time, never at eval time:

1. `packs.<name>.gameDir`, if set.
2. `appmanifest_<appid>.acf` in every Steam library → its `installdir`. This is
   authoritative and survives the game being moved to another disk.
3. `<library>/steamapps/common/<steamFolderName>`, also case-insensitively.
4. The nested-layout correction: 14 games install into a subfolder, so a
   `steamFolderName` like `The Lab/TheLab/win64` is applied relative to the
   library root.

Libraries come from `--steam-root`, else every standard root
(`$XDG_DATA_HOME/Steam`, `~/.steam/steam`, `~/.steam/root`,
`~/.local/share/Steam`, `~/Steam`, the Flatpak Steam path) plus every `path`
entry in each library's `steamapps/libraryfolders.vdf`.

The game's executable is then checked, because "mods installed but the game never
sees them" almost always means the wrong directory. A missing exe warns; pass
`--require-exe` to make it fatal.

## What gets written, and what gets taken back

Every file the installer writes is recorded in
`<gameDir>/.thunderstore-state.json` with its sha256. A later install:

* **skips** files that already hash to what we wrote (a no-op switch);
* **refuses** to overwrite a file we do not own (unless `--force`);
* **prunes** files we wrote that the pack no longer contains — but only if they
  still hash to what we wrote. A file you edited is reported and kept;
* removes directories that pruning emptied.

Delete the state file to stop tracking (or pass `--no-state`).

Because mods live inside the Steam install directory, Steam's "verify integrity"
will delete them. That is the same trade-off every ThunderStore mod manager makes:
BepInEx and MelonLoader have to be next to the game binary. Re-run
`thunderstore-install-<name>` (or the next switch) to put them back.

## Loaders

`install-rule driven` (the game's `installRules` decide where each file goes):
`bepinex`, `bepisloader`, `godotml`, `melonloader`, `northstar`, `shimloader`,
`umm`.

`hardcoded-plugin` (bespoke payload + mod routes, `installRules` is empty
upstream): `gdweave`, `lovely`, `none`, `recursive-melonloader`,
`return-of-modding`, `rivet`.

Payload and mod destinations in `lib/loaders.nix`:

| Loader | Loader payload | Mods |
|---|---|---|
| `bepinex` | whole pack minus ThunderStore's base files | `BepInEx/plugins/<Mod>/…` |
| `melonloader` | whole pack | per install rules (`Mods/`, `Plugins/`, …) |
| `recursive-melonloader` | only `MelonLoader/` + `version.dll` | `Mods/<Mod>/`, `UserData/<Mod>/` |
| `umm` | `UMM/Core`, `winhttp.dll`, `doorstop_config.ini`, … | `UMM/Mods/<Mod>/` |
| `shimloader` | `dwmapi.dll`, `ue4ss.dll` → **`<dataFolder>/Binaries/Win64/`** | `shimloader/mod/…` |
| `northstar` | whole pack | `R2Northstar/mods/` (state-tracked) |
| `godotml` | `addons/mod_loader` | `mods/<Mod>.ts.zip` (re-zipped) |
| `gdweave` | `winmm.dll`, `GDWeave/` | `GDWeave/mods/<Mod>/` |
| `lovely` | `version.dll`, `lovely/` → `mods/` | `mods/<Mod>/` |
| `return-of-modding` | whole pack | `ReturnOfModding/plugins{,_data,config}/<Mod>/` |
| `rivet` | `RivetPack/` + `version.dll` → **`Release/version.dll`** | `Rivet/Mods/<Mod>/` |
| `none` | nothing | `mods/<Mod>/` |

`shimloader` and `rivet` are why the overlay is keyed by *destination*
(`gameRoot` / `dataBinaries` / `releaseDir`) instead of a flat path list: the
router stays loader-agnostic and `install.sh` maps each name to a real directory.

Tracking methods, as implemented in `lib/route.py`:

| Method | Result |
|---|---|
| `subdir` | `<route>/<ModName>/<basename>` — flattened; a top-level `override/` dir keeps its nesting |
| `subdir-no-flatten` | `<route>/<ModName>/<full path>` |
| `state` | `<route>/<path>` verbatim, tracked (honours `relativeFileExclusions`) |
| `package-zip` | the whole mod re-zipped to `<route>/<ModName>.ts.zip` |
| `none` | `<route>/<path>` verbatim, untracked |

Rule selection per file: the longest matching `defaultFileExtensions` entry wins
(`.plugin.dll` beats `.dll`), otherwise the rule marked `isDefaultLocation`.

## Why versions are pinned with committed hashes

ThunderStore publishes **no hash** for a package zip. The CDN serves an S3
multipart ETag (`"…-44"`), which is not a content digest, and
`/api/experimental/package/` ignores every filter and is deprecated.
So `thunderstore-checksums` downloads each zip once, hashes the bytes, and commits
the pin; `nix build` then re-verifies them as fixed-output derivations. A pack
therefore either reproduces byte-identically or fails loudly.

It also resolves the dependency closure once, at pin time: `checksums.json`
contains every declared mod **and** its transitive dependencies, so the Nix build
needs no network beyond the pinned zips. Dependency versions of the *loader* are
dropped on purpose — one pinned loader, not one per mod.

## Flake outputs

| Output | Purpose |
|---|---|
| `packages.thunderstore-pack-<name>` | the built, routed profile + manifest + installer |
| `apps.thunderstore-install-<name>` | build + install into the Steam game directory |
| `apps.thunderstore-plan-<name>` | the same, `--dry-run` |
| `apps.thunderstore-game-info` | inspect the ecosystem model (`--list`, `--loaders`, `--json`) |
| `apps.thunderstore-sync` | freeze a game's ecosystem entry into `game.json` |
| `apps.thunderstore-checksums` | download + pin every package (`--check` for CI) |
| `packages.thunderstore-router-test` | end-to-end test of the install-rule router |

`install.sh` flags (also usable through `extraFlags`): `--target DIR`,
`--steam-root DIR`, `--appid ID`, `--dry-run`, `--force`, `--prune-only`,
`--no-prune`, `--require-exe`, `--no-state`, `--state-file NAME`, `--json`.

## Troubleshooting

* **"game directory not found"** — the game is not installed, or Steam's
  libraries are somewhere unusual. `--steam-root DIR` tests a specific root;
  `packs.<name>.gameDir` pins it.
* **mods install but the game ignores them** — check `ls <gameDir>/BepInEx/core`
  and that the exe check passed. With Proton, launch options sometimes need
  `WINEDLLOVERRIDES` for the loader DLL (see `my.programs.steam.games.<name>.env`).
* **Steam deleted the mods** — expected; "verify integrity" removes unknown files.
  Re-run the installer.
* **build fails with an install conflict** — two packages write the same path.
  Drop one, or set `allowConflicts` if the overwrite is intended.
* **"loader X is not modelled"** — add it to `lib/loaders.nix` first, then
  re-run the router test: `nix build .#thunderstore-router-test`.

## Sources

* Ecosystem schema: `thunderstore-io/ecosystem-schema` (`games/src/models.ts`,
  `games/misc/modloader-packages.yml`, `games/data/<slug>.yml`)
* Install semantics: `thunderstore-io/r2modmanPlus` (`InstallRulePluginInstaller`,
  `GameDirectoryResolver`, `ModLinker`), `tcli-rust` (`game/registry.rs`)
* APIs: `/api/experimental/schema/dev/latest/`,
  `/c/<community>/api/v1/package-listing-index/` (content-addressed chunk list),
  `/api/experimental/package/<ns>/<name>/<version>/`