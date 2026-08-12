# Minecraft

Minecraft client launcher with built-in Modrinth / CurseForge mod management.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `my.programs.minecraft.enable` | `false` | Enable Minecraft |
| `my.programs.minecraft.launcher` | `"prismlauncher"` | Launcher: `prismlauncher` or `modrinth-app` |
| `my.programs.minecraft.package` | `null` | Override the launcher package entirely |
| `my.programs.minecraft.jdks` | `[]` | Extra JDKs exposed to the launcher |
| `my.programs.minecraft.extraPackages` | `[]` | Extra Minecraft-related packages (ferium, mcaselector, …) |
| `my.programs.minecraft.dataDir` | `null` | Prism Launcher data dir (e.g. `/mnt/media/Modding/PrismLauncher`) |
| `my.programs.minecraft.repo.url` | `null` | Git remote (e.g. GitHub) mirroring the data dir |
| `my.programs.minecraft.repo.branch` | `null` | Branch to check out (null = current branch) |
| `my.programs.minecraft.repo.interval` | `"15m"` | Sync interval |
| `my.programs.minecraft.repo.conflictStrategy` | `"stash-and-pull"` | How to integrate remote changes |
| `my.programs.minecraft.repo.autoPush` | `false` | Push local commits after syncing |
| `my.programs.minecraft.repo.agenix.enable` | `false` | Inject GitHub token for private repos |
| `my.programs.minecraft.gamescope.enable` | `false` | Wrap launcher in gamescope |
| `my.programs.minecraft.gamescope.package` | `pkgs.gamescope` | gamescope package |

## Usage Example

```nix
my.programs.minecraft = {
  enable = true;
  extraPackages = [ pkgs.ferium pkgs.mrpack-install pkgs.mcaselector ];
  # Keep instances/libraries/assets off the system SSD:
  dataDir = "/mnt/media/Modding/PrismLauncher";
  # Auto-sync the data dir with a GitHub repo (clones on first run, pulls on interval):
  repo = {
    url = "https://github.com/Cairnstew/prismlauncher-data.git";
    interval = "30m";
    conflictStrategy = "stash-and-pull";
    autoPush = true; # push new saves / instance progress back upstream
  };
};
```

Prism Launcher (the default) provides Modrinth and CurseForge browsing/install
per instance with auto Java selection from the bundled JDK 8/17/21. Instance
data lives in `~/.local/share/PrismLauncher` by default; setting `dataDir`
relocates it via a `--dir` wrapper (applies only to the `prismlauncher`
launcher).

## Notes

- **Mods**: Prism Launcher handles Modrinth + CurseForge interactively. For
  declarative modpacks, see `nix-minecraft`
  (`fetchModrinthModpack` / `fetchPackwizModpack`) or the `packwiz` CLI.
- **Java versions**: ≤1.16.5 → Java 8–16, 1.18+ → 17, 1.20.5+ → 21. The
  wrapper bundles 8/17/21; add more via `jdks` if needed.
- **External data dir**: set `dataDir` (prismlauncher only) and migrate
  existing data once with
  `mkdir -p <dataDir> && find ~/.local/share/PrismLauncher -mindepth 1 -maxdepth 1 -exec mv {} <dataDir> \;`
  (close the launcher first).
- **Data repo sync**: setting `repo` makes the module declare its own
  `systemd` user service + timer (`minecraft-repo-sync`) that clones the repo
  into `dataDir` on first run and pulls on an interval. This mirrors the
  `my.services.gitRepoSync` machinery but lives entirely in the home module,
  so no separate gitRepoSync entry is needed. `reset-hard` is blocked by an
  assertion (the data dir holds instances and saves).
- **NVIDIA Wayland**: enable `gamescope.enable` (or set
  `__GL_THREADED_OPTIMIZATIONS=0`) for stable FPS caps/VRR. Run the wrapper as
  `minecraft-gamescope`.
- `modrinth-app` is unfree; `nixpkgs.config.allowUnfree` is set when the module
  is enabled.
- Enabled by default via `my.profiles.gaming` (override per-host if unwanted).
