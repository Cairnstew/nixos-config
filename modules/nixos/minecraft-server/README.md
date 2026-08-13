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

  # Web consoles: https://server.tail…ts.net/mc/dragon-technology/ via the
  # reverse proxy (bound to 127.0.0.1 by default).
  web.enable = true;

  servers.dragon-technology = {
    packZip = "dragon-technology.mrpack"; # exported from Prism, scp'd to packDir
    package = pkgs.neoforgeServers.neoforge-1_21_1-21_1_238;
    jvmOpts = "-Xms4G -Xmx8G";
    serverProperties = {
      max-players = 12;
      motd = "Dragon Technology";
      white-list = true;
      enable-query = true;
    };
    whitelist = { seanc = "01234567-89ab-cdef-0123-456789abcdef"; };
    operators = { seanc = "01234567-89ab-cdef-0123-456789abcdef"; };
    openFirewall = true;
  };
};
```

## Provisioning mods with packZip (the simple workflow)

1. In Prism Launcher, **zip the instance's `minecraft/` folder** (right-click
   instance → Open folder, then zip `minecraft/`) — this bundles the actual
   mod jars plus config. (A Prism "Export → Modrinth pack" `.mrpack` also
   works, but it only indexes jars by URL — you still need the jars. The full
   folder zip is self-contained.)
2. Copy the file to the server's `packDir`:
   ```bash
   scp dragon-technology.zip seanc@server:/mnt/data/minecraft/packs/
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

Two ways to get jars onto a fresh server, beyond `packZip`:

1. **Local path** — keep mods outside git, e.g.
   `pack = "/mnt/data/minecraft/packs/dragon-technology"` (a dir with
   `mods/`, `config/`, …). Symlinked at start; no Nix-store copy. Suitable for
   big packs, but must be populated manually on each machine.
2. **Declarative derivation** — export the instance as a **server-side
   `.mrpack`** and fetch it:
   ```nix
   pack = pkgs.fetchModrinthModpack {
     url = "https://example.com/packs/dragon-technology.mrpack"; # or src = <repo path>
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
servers.dragon-technology.migrateFrom =
  "/mnt/data/prismlauncher/server-data/Dragon Technology";
```

## Monitoring

Minecraft does **not** speak A2S. Options:

- `enable-query = true` in `serverProperties` → UDP Query protocol; scrape with
  e.g. `itzg/mc-monitor` for Prometheus.
- Fabric packs: add the **FabricExporter** mod (Prometheus on port 25585) — see
  the nix-minecraft README for `symlinks.mods`.
- RCON (`enable-rcon = true` + `rcon.password`) for admin commands only — never
  expose it to the internet.

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
