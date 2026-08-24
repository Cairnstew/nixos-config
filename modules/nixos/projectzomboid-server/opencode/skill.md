---
name: pz-modpack
description: Use when working with Project Zomboid servers or modpacks in this repo — defining a named modpack (a Steam Workshop item bundle + default server settings), adding a server under modules/nixos/projectzomboid-server/servers/, resolving Workshop item IDs, or reviewing what a pack/servers declares.
---

# Project Zomboid Modpack & Server Management

This repo runs Project Zomboid dedicated servers via
`my.services.projectZomboid` (`modules/nixos/projectzomboid-server/`). The
server is the native Linux dedicated server (SteamCMD app **380870**), installed
and updated with `steamcmd`, then driven as a headless Java process under
`steam-run`. Mods are Steam **Workshop** items (game app **108600**), downloaded
by steamcmd and referenced by the server `.ini`.

## Where modpacks live

A modpack is a **named, git-tracked bundle** of Workshop mods plus optional
default server settings. Each modpack is one file in
`modules/nixos/projectzomboid-server/modpacks/<name>.nix` that sets
`my.services.projectZomboid.modpacks.<name>`:

```nix
my.services.projectZomboid.modpacks.my-pack = {
  description = "...";
  workshopMods = [
    { id = "2625441155"; title = "Brita's Armor Pack"; }
  ];
  mods = [ ];                       # local / non-Workshop mod folder names
  defaultSettings = { PVP = true; };   # defaults applied to any server using it
  defaultSandbox = { Zombies = 3; };   # default SandboxVars
};
```

Register it in `modpacks/default.nix` imports. A server picks a pack via
`servers.<name>.modpack`.

## Where servers live

One file per server under `modules/nixos/projectzomboid-server/servers/<name>.nix`
(`servers.<name>`), **disabled by default** — enable from a host config or profile:

```nix
my.services.projectZomboid.servers.knox = {
  enable = true;                 # or lib.mkDefault false in the catalog, opt in
  modpack = "my-pack";           # the named pack above
  name = "knox";                 # -> Zomboid/Server/knox.ini, Saves/Multiplayer/knox
  map = "Muldraugh, KY";
  defaultPort = 16261;           # UDP
  udpPort = 16262;               # UDP (direct connection)
  openFirewall = true;
  jvmOpts = "-Xmx6G -Xms3G -XX:+UseZGC";
  settings = { PVP = true; };
  sandbox  = { Zombies = 4; };
};
```

## Workshop item IDs

Each mod's Steam Workshop page URL is
`https://steamcommunity.com/sharedfiles/filedetails/?id=<id>`. Put the numeric
`id` in `workshopMods`. The module downloads each into the shared install
`steamapps/workshop/content/108600/<id>`, symlinks it into each server's
`Zomboid/Workshop/content/108600/<id>`, and writes `WorkshopItems=` +
`Mods=` into the `.ini`. Clients auto-download the Workshop items on join.

- **modworkshop.net** mods are NOT Workshop items — add them via a server/modpack
  `mods` list and place their folders in the shared install's `Zomboid/mods`.
- Verify each `id` is current for the server's build (41 / 42).

## Check a pack / servers

Use the `pz-modpack-status` tool to list the defined modpacks/servers and their
Workshop IDs (read-only, no host needed):

```
pz-modpack-status             # summarize all
pz-modpack-status {"modpack":"vanilla-plus"}   # detail one pack
```

## Deploying / updating

The module creates:

- `projectzomboid-<name>.service` — one dedicated server unit (steam-run +
  `start-server.sh -servername <name>`), with a `control.fifo` console.
- `project-zomboid-update.service` / optional timer — `steamcmd` install of
  app 380870 + downloads all Workshop items, restarts servers after.
- `pz-web-<name>.service` — optional ttyd web console (if `web.enable`).

Shutdown sends `save` then `quit` to the FIFO for a clean world save. See the
module `README.md` for options.
