# Game Servers

Declarative management of Steam (and generic) dedicated game servers via `steamcmd`, each running as a hardened systemd service with optional A2S Prometheus monitoring.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `my.services.game-servers.enable` | `false` | Enable the module |
| `my.services.game-servers.user` | `"game-servers"` | Service user |
| `my.services.game-servers.group` | `"game-servers"` | Service group |
| `my.services.game-servers.dataDir` | `"/var/lib/game-servers"` | Base install dir (e.g. `/mnt/data/game-servers`) |
| `my.services.game-servers.servers.<name>.appId` | — | Steam App ID of the dedicated server |
| `my.services.game-servers.servers.<name>.startCommand` | — | Server binary relative to `stateDir` |
| `my.services.game-servers.servers.<name>.args` | `[]` | Extra server args |
| `my.services.game-servers.servers.<name>.autoUpdate` | `true` | steamcmd update at every service start |
| `my.services.game-servers.servers.<name>.validate` | `false` | `+app_update … validate` (full file check) |
| `my.services.game-servers.servers.<name>.branch` | `null` | Steam beta branch |
| `my.services.game-servers.servers.<name>.stateDir` | `null` | Install dir (defaults to `dataDir/<name>`) |
| `my.services.game-servers.servers.<name>.updateSchedule` | `null` | Optional timer (e.g. `"daily"`) for periodic updates |
| `my.services.game-servers.servers.<name>.openFirewall` | `false` | Open `ports` in the firewall |
| `my.services.game-servers.servers.<name>.ports` | `[]` | `{ port, protocol }` list to expose |
| `my.services.game-servers.servers.<name>.monitoring.enable` | `false` | A2S exporter for this server |
| `my.services.game-servers.servers.<name>.monitoring.queryPort` | `null` | A2S query port (game port + 1) |
| `my.services.game-servers.servers.<name>.monitoring.exporterPort` | `9841` | Metrics port |
| `my.services.game-servers.monitoring.enable` | `false` | Enable the exporter units |

## Usage

```nix
my.services.game-servers = {
  enable = true;
  dataDir = "/mnt/data/game-servers";

  servers.cs2 = {
    appId = "740";
    startCommand = "game/bin/linuxsteamrt64/cs2";
    args = [ "-dedicated" "-usercon" "-port 27015" "-maxplayers 12" ];
    ports = [
      { port = 27015; protocol = "udp"; }
      { port = 27015; protocol = "tcp"; }
    ];
    openFirewall = true;
    updateSchedule = "daily";
    monitoring = { enable = true; queryPort = 27015; exporterPort = 9841; };
  };
};

my.services.game-servers.monitoring.enable = true;
```

## Notes

- **LinuxGSM is not used** — it's imperative and unmaintainable on NixOS. `steamcmd` + systemd is the Nix-native approach.
- Servers run via `steam-run` (FHS, bwrap) — do **not** add `NoNewPrivileges`/`PrivateMounts` in `extraServiceConfig`; bwrap conflicts with strict systemd sandboxing.
- `pkgs.steamcmd` fetches its installer from the Wayback Machine (Valve's CDN is dead) — see `GOTCHAS.md`.
- Metrics are exposed on `127.0.0.1:<exporterPort>`; wire them into a Prometheus scrape job yourself (no Prometheus module exists in this repo yet).
- The exporter package defaults to the in-repo `a2s-exporter` (see `packages/a2s-exporter`).
