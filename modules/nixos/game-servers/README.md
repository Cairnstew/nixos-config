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
| `my.services.game-servers.servers.<name>.autoUpdate` | `false` | steamcmd update at every service start (off by default) |
| `my.services.game-servers.servers.<name>.validate` | `false` | `+app_update … validate` (full file check) |
| `my.services.game-servers.servers.<name>.branch` | `null` | Steam beta branch |
| `my.services.game-servers.servers.<name>.login.user` | `"anonymous"` | Steam account used for the update |
| `my.services.game-servers.servers.<name>.login.passwordFile` | `null` | File with the Steam password (e.g. agenix); mutually exclusive with `onepassword.reference` |
| `my.services.game-servers.servers.<name>.login.onepassword.reference` | `null` | 1Password `op://` reference for the Steam password, resolved with `op read` at run time |
| `my.services.game-servers.servers.<name>.login.onepassword.tokenFile` | `null` | File with a 1Password service-account token (e.g. agenix), read into `OP_SERVICE_ACCOUNT_TOKEN` |
| `my.services.game-servers.servers.<name>.login.onepassword.package` | `pkgs._1password-cli` | 1Password CLI (`op`) |
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

## Login-required servers (1Password)

Some depots only download for an account that owns the game. Give the server a
Steam password from 1Password, resolved with `op read` on every update:

```nix
my.services.game-servers.servers.<name>.login = {
  user = "my-steam-account";
  onepassword = {
    reference = "op://Private/Steam/password";
    # A system service cannot `op signin` interactively, so hand it a
    # service-account token. This is an agenix secret path.
    tokenFile = "/run/agenix/onepassword-token";
  };
};
```

The token file must be readable by the `game-servers` service user, so its
agenix manifest entry needs an appropriate owner/group/mode.

**SteamCMD still needs a one-time interactive login per `HOME`.** The password
above only re-authenticates on each run; the account's login token is cached in
the server's `stateDir` (its `HOME`), and the *first* login from a machine also
needs a Steam Guard code that cannot be automated. Log in once by hand
(`HOME=<stateDir> steamcmd +login <account>`), after which the cached token is
reused — see `GOTCHAS.md` ("A `steamcmd` login is cached per-`HOME`").

## Notes

- **LinuxGSM is not used** — it's imperative and unmaintainable on NixOS. `steamcmd` + systemd is the Nix-native approach.
- Servers run via `steam-run` (FHS, bwrap) — do **not** add `NoNewPrivileges`/`PrivateMounts` in `extraServiceConfig`; bwrap conflicts with strict systemd sandboxing.
- `pkgs.steamcmd` fetches its installer from the Wayback Machine (Valve's CDN is dead) — see `GOTCHAS.md`.
- Metrics are exposed on `127.0.0.1:<exporterPort>`; wire them into a Prometheus scrape job yourself (no Prometheus module exists in this repo yet).
- The exporter package defaults to the in-repo `a2s-exporter` (see `packages/a2s-exporter`).
