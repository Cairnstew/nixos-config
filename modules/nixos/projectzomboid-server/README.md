# Project Zomboid Server

Declarative [Project Zomboid](https://projectzomboid.com/) dedicated servers
via SteamCMD (app **380870**) — the native Linux dedicated server run as a
headless Java process under `steam-run` — with **clean, git-tracked modpack
definitions** (Steam Workshop item bundles) and **per-server** config, sandbox,
firewall, hardware caps, a FIFO console, and optional ttyd web consoles.
Mimics the structure of the `minecraft-server` module.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `my.services.projectZomboid.enable` | `false` | Enable the module |
| `my.services.projectZomboid.user` / `.group` | `project-zomboid` | Service user/group |
| `my.services.projectZomboid.dataDir` | `/mnt/data/project-zomboid` | Base dir (server install + per-server homes) |
| `my.services.projectZomboid.updateOnStart` | `false` | steamcmd update at every server start |
| `my.services.projectZomboid.updateSchedule` | `null` | Optional update timer (e.g. `"daily"`) |
| `my.services.projectZomboid.modpacks` | `{}` | Named modpack definitions (`modpacks/`) |
| `my.services.projectZomboid.servers` | `{}` | Per-server definitions (`servers/`) |
| `my.services.projectZomboid.web.enable` | `false` | ttyd web consoles |
| `my.services.projectZomboid.web.portBase` | `7681` | First console port |
| `my.services.projectZomboid.servers.<name>.modpack` | `null` | Named modpack to apply |
| `my.services.projectZomboid.servers.<name>.map` | `"Muldraugh, KY"` | Map |
| `my.services.projectZomboid.servers.<name>.defaultPort` | `16261` | Game port (UDP) |
| `my.services.projectZomboid.servers.<name>.udpPort` | `16262` | Direct-connection port (UDP) |
| `my.services.projectZomboid.servers.<name>.settings` | `{}` | Declarative `.<name>.ini` overrides |
| `my.services.projectZomboid.servers.<name>.sandbox` | `{}` | Declarative `_SandboxVars.lua` overrides |
| `my.services.projectZomboid.servers.<name>.jvmOpts` | `-Xmx4G -Xms2G` | JVM flags |
| `my.services.projectZomboid.servers.<name>.hardware` | `{}` | systemd memory/CPU/scheduler caps |

## Usage Example

```nix
my.services.projectZomboid = {
  enable = true;
  dataDir = "/mnt/data/project-zomboid";
  web.enable = true;
  updateOnStart = true;   # steamcmd update app 380870 on every start
  # updateSchedule = "daily";  # or a periodic timer

  modpacks.vanilla-plus = { ... };   # usually defined in modpacks/ instead
  servers.knox = { ... };            # usually defined in servers/ instead
};
```

## Modpacks (define them cleanly)

A modpack is a named, git-tracked bundle of Steam Workshop items (plus optional
default server settings) declared in
`modules/nixos/projectzomboid-server/modpacks/<name>.nix`. One server or many
can reference a pack by name; to reuse a pack just point another server at it.

```nix
# modules/nixos/projectzomboid-server/modpacks/vanilla-plus.nix
{
  my.services.projectZomboid.modpacks.vanilla-plus = {
    description = "A small Vanilla+ bundle";
    workshopMods = [
      { id = "2625441155"; title = "Brita's Armor Pack"; }
      { id = "2625840413"; title = "Brita's Weapon Pack"; }
    ];
    mods = [ ];                       # local / non-Workshop mod folders
    defaultSettings = { PVP = true; PauseEmpty = true; };
    defaultSandbox  = { Zombies = 3; DayLength = 4; };
  };
}
```

Workshop IDs come from each mod's Steam page
(`https://steamcommunity.com/sharedfiles/filedetails/?id=<id>`). The module
downloads them into the shared install (`steamapps/workshop/content/108600/<id>`),
writes `WorkshopItems=` + `Mods=` into the server `.ini`, and clients auto-download
on join. **modworkshop.net** mods aren't Workshop items — add them via a
`mods` list (place their folders in the install's `Zomboid/mods`).

## Servers

Each server is defined **in full** in its own file under
`modules/nixos/projectzomboid-server/servers/<name>.nix` (one file per server)
and **disabled by default** — opt in from a host config or profile:

```nix
my.services.projectZomboid.servers.knox.enable = true;   # host/profile
```

Example (`servers/knox.nix`):

```nix
{ lib, ... }:
{
  my.services.projectZomboid.servers.knox = {
    enable = lib.mkDefault false;
    modpack = "vanilla-plus";
    name = "knox";             # -> Zomboid/Server/knox.ini, Saves/Multiplayer/knox
    map = "Muldraugh, KY";
    defaultPort = 16261;       # UDP
    udpPort = 16262;           # UDP (direct connection)
    openFirewall = true;
    jvmOpts = "-Xmx6G -Xms3G -XX:+UseZGC";
    settings = { PVP = true; AnnounceDeath = true; };
    sandbox  = { Zombies = 3; MultiHitZombies = true; };
  };
}
```

The module builds a `.<name>.ini` (merged in place so PZ's runtime world-identity
keys like `Seed`/`ResetID` are preserved) and a fresh `_SandboxVars.lua` on every
start. `settings` win over a modpack's `defaultSettings`; `sandbox` wins over
`defaultSandbox`.

## Web console

With `web.enable = true`, each server gets a `pz-web-<name>` ttyd console (bound
to `web.bind`, default loopback) that streams `Zomboid/Logs/server.txt`, forwards
typed lines to the server console FIFO, and supports dot-commands
`.status` / `.start` / `.stop` / `.restart`. Consoles run as
`web.user` (in the PZ group with scoped passwordless sudo for the PZ units) and
auto-register on the proxy dashboard at `/pz/<name>/`.

## Console, shutdown & updates

- Send commands via the FIFO: `echo "help" > /mnt/data/project-zomboid/knox/control.fifo`
  (or use the web console).
- `systemctl stop projectzomboid-knox` triggers the graceful `save` → `quit`
  sequence; an in-game `quit` restarts it (`restart = "on-failure"` default).
- `project-zomboid-update.service` runs the steamcmd install of app 380870 +
  Workshop downloads; `updateOnStart`/`updateSchedule` control when.
- Manage state: `journalctl -u projectzomboid-<name> -f` for logs.

## Notes

- The dedicated server is **native Linux** (bundled JRE). It runs via `steam-run`
  (bwrap FHS), so avoid strict sandboxing in `extraServiceConfig`.
- Each server needs **two free UDP ports** (game + direct connect); default is
  16261/16262 for the first, 16274/16275 etc. for more (per the wiki).
- The Devs advise against systemd but support it — the FIFO + `save`/`quit`
  shutdown here follows their documented pattern.
- `.ini` merge preserves PZ-generated keys; the sandbox lua is fully overwritten
  each start (declare all your sandbox vars declaratively).
