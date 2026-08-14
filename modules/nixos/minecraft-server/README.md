# Minecraft Server

Declarative Minecraft dedicated servers via the [nix-minecraft](https://github.com/Infinidoge/nix-minecraft)
flake — vanilla, Fabric, NeoForge, Paper, Purpur and Velocity — with modpack
support via dropped `.zip`/`.mrpack` files, declarative `fetchModrinthModpack`
derivations, and a per-server **web console** for monitoring and start/stop.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `my.services.minecraftServer.enable` | `false` | Enable the module |
| `my.services.minecraftServer.eula` | `false` | Accept Mojang's EULA (required) |
| `my.services.minecraftServer.dataDir` | `/mnt/data/minecraft` | Base data dir for all servers |
| `my.services.minecraftServer.packDir` | `/mnt/data/minecraft/packs` | Drop directory for modpack zips (scp here) |
| `my.services.minecraftServer.openFirewall` | `false` | Open ports for all servers |
| `my.services.minecraftServer.managementSystem` | `{ systemdSocket.enable = true; }` | Console system: systemd-socket (default) or tmux |
| `my.services.minecraftServer.web.enable` | `false` | Per-server ttyd web consoles |
| `my.services.minecraftServer.web.portBase` | `7681` | First console port (base + sorted index) |
| `my.services.minecraftServer.web.bind` | `"127.0.0.1"` | Console bind address |
| `my.services.minecraftServer.web.user` | `"minecraft-web"` | Console user (in group `minecraft`) |
| `my.services.minecraftServer.web.username` / `.passwordFile` | `null` | Optional basic auth |
| `my.services.minecraftServer.web.proxyUpstream` | `true` | Register consoles on the proxy dashboard |
| `my.services.minecraftServer.servers.<name>.enable` | `true` | Run this server |
| `my.services.minecraftServer.servers.<name>.package` | — | Server package (e.g. `pkgs.neoforgeServers.neoforge-1_21_1-21_1_238`) |
| `my.services.minecraftServer.servers.<name>.jvmOpts` | `"-Xmx4G -Xms2G"` | JVM flags |
| `my.services.minecraftServer.servers.<name>.port` | `25565` | Game port (merged into serverProperties) |
| `my.services.minecraftServer.servers.<name>.autoStart` | `true` | Start at boot |
| `my.services.minecraftServer.servers.<name>.serverProperties` | `{}` | Declarative server.properties |
| `my.services.minecraftServer.servers.<name>.whitelist` | `{}` | Username → UUID map |
| `my.services.minecraftServer.servers.<name>.operators` | `{}` | Username → UUID map |
| `my.services.minecraftServer.servers.<name>.openFirewall` | `false` | Open this server's ports |
| `my.services.minecraftServer.servers.<name>.packZip` | `null` | Modpack zip/mrpack in `packDir` to unpack at start |
| `my.services.minecraftServer.servers.<name>.restartOnZipChange` | `true` | Auto-restart server when `packZip` changes |
| `my.services.minecraftServer.servers.<name>.packwiz` | `null` | Path to a packwiz modpack dir in this flake (built via packwiz2nix) |
| `my.services.minecraftServer.servers.<name>.pack` | `null` | Modpack content dir or `fetchModrinthModpack` derivation |
| `my.services.minecraftServer.servers.<name>.migrateFrom` | `null` | Copy world from an old server-data dir on first start |
| `my.services.minecraftServer.servers.<name>.extraSymlinks` | `{}` | Extra path → data-dir symlinks |
| `my.services.minecraftServer.servers.<name>.restart` | `"on-failure"` | systemd Restart policy |
| `my.services.minecraftServer.servers.<name>.managementSystem` | inherit | Per-server console system override |
| `my.services.minecraftServer.servers.<name>.web.enable` / `.web.port` | `true` / `null` | Per-server console toggle / port override |

## Usage Example

```nix
my.services.minecraftServer = {
  enable = true;
  eula = true;
  dataDir = "/mnt/data/minecraft";
  packDir = "/mnt/data/minecraft/packs"; # scp modpack zips here
  web.enable = true;
};
```

## Server definitions (the servers/ folder)

Each server is defined **in full** in its own file under
`modules/nixos/minecraft-server/servers/` — one file per server, everything
about that server in one place. Add a new server by creating a file there and
listing it in `servers/default.nix`.

A server definition sets `my.services.minecraftServer.servers.<name>` and is
**disabled by default** (`enable = lib.mkDefault false`), so defining a server
never starts it. Enable the servers you want from a host config or a profile:

```nix
# host or profile
my.services.minecraftServer.servers.test.enable = true;
# or, from a profile (e.g. my.profiles.gaming.minecraftServers):
my.profiles.gaming.minecraftServers = [ "test" ];
```

Example definition (`servers/test.nix`):

```nix
{ lib, pkgs, ... }:
{
  my.services.minecraftServer.servers.test = {
    enable = lib.mkDefault false;
    package = pkgs.vanillaServers.vanilla-1_21_1;
    jvmOpts = "-Xmx2G -Xms1G";
    port = 25565;
    serverProperties = {
      motd = "A NixOS Test Server";
      max-players = 4;
    };
  };
}
```

## Provisioning mods with packwiz (declarative, reproducible)

The most declarative workflow: author the modpack with the
[packwiz CLI](https://packwiz.infra.link) in the repo's `modpacks/` directory,
then [packwiz2nix](https://github.com/getchoo/packwiz2nix) turns it into
hash-verified fixed-output derivations that are symlinked into the server's
`mods/` at start. No zips to scp, no manual jar management — the pack is just
git-tracked metadata.

### 1. Author the pack

Modpacks live in `modules/nixos/minecraft-server/modpacks/<pack>/`. The flake
exposes the packwiz CLI as `.#packwiz` and one checksum app per pack; the
`just` recipes wrap them so you don't have to chase paths:

```bash
just packwiz testModpack init                 # create pack.toml + index.toml
just packwiz testModpack modrinth add <mod>   # add mods from Modrinth
just packwiz testModpack update --all         # bump mods
```

(`just packwiz <pack> ...` cd's into the modpack dir and runs
`nix run <repo>#packwiz -- ...`; packwiz operates on the current directory.)

Each mod becomes a `<pack>/mods/<name>.pw.toml` metadata file. Any mod added
via `curseforge` will fail checksum generation — packwiz2nix has no CurseForge
support (no URL is kept in the metadata); prefer Modrinth.

### 2. Generate checksums

packwiz verifies mods with SHA-1, which Nix fetchers can't use, so packwiz2nix
needs a SHA-256 `checksums.json`. Regenerate it whenever the pack changes:

```bash
just packwiz-checksums testModpack            # writes checksums.json (commit it!)
```

This downloads every mod jar (at runtime, when the app runs) and records its
SHA-256 — no `--impure` needed, and `nix flake check` stays green. Commit
`checksums.json` so fresh machines can build the pack.

> **CurseForge mods:** packwiz stores CurseForge mods as `mode = "metadata:curseforge"`
> with **no download URL** — packwiz2nix cannot fetch them, so checksum generation
> fails. Convert them to Modrinth (`packwiz modrinth add <slug>`) or to a direct
> URL (`packwiz url add <url>` — the CurseForge CDN URL is derivable from the
> mod's file-id: `https://edge.forgecdn.net/files/<id//1000>/<id%1000>/<filename>`).
> The testModpack was fully converted this way (255/255 have URLs).

> **Gotcha:** Nix flakes only snapshot **git-tracked** files, so a modpack's
> `packwiz-checksums-<pack>` app only appears once its files are `git add`ed
> (staging is enough for the flake to see them). Add the pack's files after
> each edit before running the checksum app.

### 3. Point a server at the pack

```nix
my.services.minecraftServer.servers.my-server = {
  enable = true;
  package = pkgs.fabricServers.fabric-1_21_1;  # must match the pack's loader
  packwiz = ../modpacks/testModpack;           # relative to the server def
  # packwiz = (flake inputs self) + "/modules/nixos/minecraft-server/modpacks/testModpack";
};
```

The module reads `<pack>/checksums.json`, builds every mod with
`mkPackwizPackages`, and symlinks them into the data dir's `mods/` via
`mkModLinks` (nix-minecraft's `symlinks`, which permits `/nix/store`). The
pack's internal content — `config/` (default player configs), Paxi datapacks
under `config/paxi/datapacks`, `kubejs/`, `scripts/` — is symlinked into the
data dir at server start too, so shipped defaults and patches reach the server.
If `checksums.json` is missing the server starts without mods and the build
warns.

> The server's `package` loader/version must match the pack's `pack.toml`
> (`minecraft` + `modloader`). The mod jars are symlinked regardless; a
> mismatched loader simply won't load them.

### 4. Ship default player configs & datapack patches

Files dropped under the pack's `config/` are indexed by packwiz and copied to
players on install — this is how you ship **default mod configs** (e.g.
`config/jei/jei.toml`). For each config decide the index.toml `preserve` flag
(`packwiz-config-preserve`): `true` installs only when absent (player edits
win), no flag overwrites on every install. Review an override against the
mod's stock default with `packwiz-config-diff`.

**Patches** ship as datapacks via Paxi (`config/paxi/datapacks/`,
`packwiz-datapack-add`), loaded into every world including servers. `pack.mcmeta`
`pack_format` must match the pack's MC version (1.21.1 = 48). KubeJS
(`kubejs/`) and CraftTweaker (`scripts/`) are the script-based patch route.
These internal files deploy to the server via the same packwiz symlink step.

### 5. Manual client build / update (no system rebuild)

The same pack builds into Prism Launcher instances. On hosts that declare
`my.programs.minecraft.instances.<name>`, a systemd timer keeps them in sync —
but you can also do it by hand, without touching the rest of the system:

```bash
# Build + install client content into a Prism instance dir. Default dataDir is
# config.minecraft.dataDir (external media drive, see config.nix) or
# ~/.local/share/PrismLauncher if unset. Optional 2nd arg = server to auto-join.
nix run .#modpack-build-testModpack
nix run .#modpack-build-testModpack /mnt/media/Modding/PrismLauncher server.tail685690.ts.net:25565

# Full manual update: regenerate checksums.json, rebuild, reinstall.
# Run from the repo root (it stages checksums.json, so commit after).
nix run .#modpack-update-testModpack [dataDir] [server]
```

Shortcuts: `just modpack-build <pack> [dataDir]`, `just modpack-update <pack> [dataDir]`.
Both use the same instance layout code as the home-module timer
(`modules/flake-parts/packwiz-instance-sync.py`), so the manual result is
identical to the declarative one. If you don't pass a server, an existing
`[JoinServerOnLaunch]` address in the instance is preserved.

## Provisioning mods with packZip (the simple workflow)

1. In Prism Launcher, **zip the instance's `minecraft/` folder** (right-click
   instance → Open folder, then zip `minecraft/`) — this bundles the actual
   mod jars plus config. (A Prism "Export → Modrinth pack" `.mrpack` also
   works, but it only indexes jars by URL — you still need the jars. The full
   folder zip is self-contained.)
2. Copy the file to the server's `packDir`:
   ```bash
   scp my-pack.zip seanc@server:/mnt/data/minecraft/packs/
   ```
3. **That's it** — by default (`restartOnZipChange = true`) a `systemd.path`
   watcher notices the new/changed zip, restarts the server automatically, and
   the new pack is unpacked. No manual restart needed. (Set
   `restartOnZipChange = false` to keep restarts manual.)

On start the module unpacks the zip's `mods`, `config`, `kubejs`, `scripts`,
`datapacks` and `defaultconfigs` into the data dir. Unpacking only happens when
the zip's SHA-256 **changes** (tracked by a stamp file), so restarting an
unchanged server never clobbers runtime-modified config. The watcher applies
the same hash check, so scp's temp-file+rename sequence (which fires the path
unit twice) restarts the server exactly once. `packDir` is owned by the primary
user (group `minecraft`) so scp works without sudo.

Three zip layouts are detected automatically:

- a Prism instance zip (contains a top-level `minecraft/`),
- an `.mrpack` / CurseForge pack (contains `overrides/`),
- a bare modpack zip (content dirs at the root).

`world/` is never unpacked from a zip — live worlds come from `migrateFrom` or
fresh generation and are never clobbered.

## Mods on fresh machines

Three ways to get jars onto a fresh server, beyond `packZip`:

1. **packwiz modpack (recommended)** — `servers.<name>.packwiz = ../modpacks/<pack>`
   builds every mod as a hash-verified fixed-output derivation from the
   pack's `checksums.json` (see "Provisioning mods with packwiz").
2. **Local path** — keep mods outside git, e.g.
   `pack = "/mnt/data/minecraft/packs/my-pack"` (a dir with
   `mods/`, `config/`, …). Symlinked at start; no Nix-store copy. Suitable for
   big packs, but must be populated manually on each machine.
2. **Declarative derivation** — export the instance as a **server-side
   `.mrpack`** and fetch it:
   ```nix
   pack = pkgs.fetchModrinthModpack {
     url = "https://example.com/packs/my-pack.mrpack"; # or src = <repo path>
     packHash = "sha256-…";
     side = "server";   # auto-filters client-only mods (OptiFine, shaders, …)
   };
   ```
   Hash-verified, reproducible, works on fresh machines. `fetchModrinthModpack`
   accepts `src` (a committed `.mrpack` or extracted dir) or `url`.

## Web console

With `web.enable = true`, each server gets `systemd.services.mc-web-<name>` —
a `ttyd` terminal bound to `web.bind` (default loopback) that:

- streams the server log (`tail -F logs/latest.log`),
- forwards typed lines to the server console FIFO (`/run/minecraft/<name>.stdin`),
- supports dot-commands `.status`, `.start`, `.stop`, `.restart`.

Consoles run as `web.user` (created in group `minecraft`, with scoped
passwordless sudo for `systemctl {start,stop,restart,status}
minecraft-server-*`). They auto-register on the proxy dashboard at
`/mc/<name>/`. Start/stop buttons are the terminal's dot-commands — an in-game
`/stop` would restart the server (`restart = "on-failure"` default).

The web console **requires** the `systemd-socket` management system (the
default) — it has no FIFO under `tmux` management.

## Console & management

- Default `systemd-socket`: `echo 'list' > /run/minecraft/<name>.stdin`,
  logs via `journalctl -u minecraft-server-<name> -f`.
- `tmux` mode: `tmux -S /run/minecraft/<name>.sock attach`, `Ctrl-b d` to detach.
- Stop a server with `systemctl stop minecraft-server-<name>` (an in-game `/stop`
  restarts it because `restart` defaults to `on-failure`).

## Migrating an existing server

If you already ran a server under `server-data/<instance>/` (the old Prism
flake approach), point `migrateFrom` at it — on first start the module copies
`world/` and `usercache.json` into the new `dataDir/<name>/` (idempotent):

```nix
servers.my-server.migrateFrom =
  "/mnt/data/prismlauncher/server-data/My Old Server";
```

## Monitoring

Minecraft does **not** speak A2S. Options:

- `enable-query = true` in `serverProperties` → UDP Query protocol; scrape with
  e.g. `itzg/mc-monitor` for Prometheus.
- Fabric packs: add the **FabricExporter** mod (Prometheus on port 25585) — see
  the nix-minecraft README for `symlinks.mods`.
- RCON (`enable-rcon = true` + `rcon.password`) for admin commands only — never
  expose it to the internet.

## OpenCode integration

Enabling this module also wires modpack utilities into the user's
[opencode](https://opencode.ai) config (`my.programs.opencode`), via
`my.homeManager.extraConfig` — so agents can edit/verify modpacks directly:

- **CLI tools**: `packwiz` (run the CLI inside a pack), `packwiz-checksums`
  (regenerate `checksums.json`), `mc-pack-status` (verify the pack, including
  internal files and datapack pack_formats).
- **Config tools** (default player configs): `packwiz-config-add`,
  `packwiz-config-preserve`, `packwiz-config-list`, `packwiz-config-diff`.
- **Patch tools** (Paxi datapacks): `packwiz-datapack-add`,
  `packwiz-datapack-remove`.
- **Version / QA tools**: `packwiz-mod-pin`, `packwiz-inspect-mod`,
  `packwiz-update-safe`.
- **Skill** `mc-modpack`: the packwiz/checksum/CurseForge-conversion workflow
  plus the config/patch tooling.
- **Command** `/mc-modpack`: orchestrated add/convert/config/patch/verify flow.

Toggle with `my.services.minecraftServer.opencode.enable` (default `true`;
only applied on hosts that also enable opencode). Files live in
`modules/nixos/minecraft-server/opencode/`; the config/patch logic is in
`opencode/tools/mc-pack.py`.

## Notes

- The nix-minecraft module hardens the systemd unit itself (sandboxing,
  crash-loop protection, auto firewall ports). Add a memory cap by augmenting
  the generated unit directly, e.g.
  `systemd.services.minecraft-server-<name>.serviceConfig.MemoryMax = "12G";`.
- The overlay is applied automatically by this module (`nixpkgs.overlays`),
  so `pkgs.neoforgeServers.*` / `pkgs.paperServers.*` / `pkgs.vanillaServers.*`
  are available when the module is enabled.
- Mods are provisioned via `packZip` (drop a zip in `packDir`) or `pack`
  (see "Provisioning mods with packZip" / "Mods on fresh machines").
