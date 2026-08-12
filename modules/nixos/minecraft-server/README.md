# Minecraft Server

Declarative Minecraft dedicated servers via the [nix-minecraft](https://github.com/Infinidoge/nix-minecraft)
flake — vanilla, Fabric, NeoForge, Paper, Purpur and Velocity — with optional
modpack support for Prism Launcher exports.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `my.services.minecraftServer.enable` | `false` | Enable the module |
| `my.services.minecraftServer.eula` | `false` | Accept Mojang's EULA (required) |
| `my.services.minecraftServer.dataDir` | `/mnt/data/minecraft` | Base data dir for all servers |
| `my.services.minecraftServer.openFirewall` | `false` | Open ports for all servers |
| `my.services.minecraftServer.servers.<name>.enable` | `true` | Run this server |
| `my.services.minecraftServer.servers.<name>.package` | — | Server package (e.g. `pkgs.neoforgeServers.neoforge-1_21_1-21_1_238`) |
| `my.services.minecraftServer.servers.<name>.jvmOpts` | `"-Xmx4G -Xms2G"` | JVM flags |
| `my.services.minecraftServer.servers.<name>.serverProperties` | `{}` | Declarative server.properties |
| `my.services.minecraftServer.servers.<name>.whitelist` | `{}` | Username → UUID map |
| `my.services.minecraftServer.servers.<name>.operators` | `{}` | Username → UUID map |
| `my.services.minecraftServer.servers.<name>.openFirewall` | `false` | Open this server's ports |
| `my.services.minecraftServer.servers.<name>.pack` | `null` | Modpack content dir (symlinked into data dir) |
| `my.services.minecraftServer.servers.<name>.extraSymlinks` | `{}` | Extra path → data-dir symlinks |
| `my.services.minecraftServer.servers.<name>.restart` | `"on-failure"` | systemd Restart policy |
| `my.services.minecraftServer.servers.<name>.managementSystem` | `{ tmux.enable = true; }` | Console: tmux or systemd-socket |

## Usage Example

```nix
my.services.minecraftServer = {
  enable = true;
  eula = true;
  dataDir = "/mnt/data/minecraft";

  servers.dragon-technology = {
    package = pkgs.neoforgeServers.neoforge-1_21_1-21_1_238;
    jvmOpts = "-Xms4G -Xmx8G";
    pack = ./packs/dragon-technology; # Prism export's minecraft/ dir, server-safe
    serverProperties = {
      server-port = 25565;
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

## Prism Launcher → server pack

Prism cannot run a dedicated server (it's a client launcher), but a modpack
export is the right input:

1. In Prism, export the instance as a **Modrinth `.mrpack`** (server-aware, has
   `env` flags + `server-overrides/`) OR export as a MultiMC `.zip`.
2. Extract the server-relevant content into a directory and point `pack` at it.
   The module symlinks `mods`, `config`, `kubejs`, `scripts`, `datapacks`,
   `defaultconfigs` from the pack into the server data dir.
3. For a `.mrpack`, prefer a derivation instead:
   ```nix
   pack = pkgs.fetchModrinthModpack {
     url = "https://cdn.modrinth.com/data/….mrpack";
     packHash = "sha256-…";
     side = "server";
   };
   ```

EULA: set `eula = true` (the module writes `eula.txt` for you).

## Console & management

- Default `tmux`: `tmux -S /run/minecraft/<name>.sock attach`, `Ctrl-b d` to detach.
- `systemd-socket` mode: `echo 'list' > /run/minecraft/<name>.stdin`.
- Stop a server with `systemctl stop minecraft-server-<name>` (an in-game `/stop`
  restarts it because `restart` defaults to `on-failure`).

## Monitoring

Minecraft does **not** speak A2S (the `game-servers` a2s-exporter does not
apply). Options:

- `enable-query = true` in `serverProperties` → UDP Query protocol; scrape with
  e.g. `itzg/mc-monitor` for Prometheus.
- Fabric packs: add the **FabricExporter** mod (Prometheus on port 25585,
  Grafana dashboard 14492) — see the nix-minecraft README for `symlinks.mods`.
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
