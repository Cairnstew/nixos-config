# modules/nixos/projectzomboid-server/lib.nix
# Shared derivation helpers for the Project Zomboid module: rendering the
# <servername>.ini and <servername>_SandboxVars.lua files Project Zomboid reads,
# and resolving the effective (module-merged) config for a server. Imported by
# config.nix and services.nix.
{ lib }:

let
  # ── Value rendering ────────────────────────────────────────────────────────
  # A .ini / lua value. Strings with inner spaces are safe unquoted in the .ini;
  # booleans render as true/false. For the lua we keep numbers and booleans raw
  # and quote strings.
  renderIniValue = v:
    if builtins.isBool v then (if v then "true" else "false")
    else if builtins.isString v then v
    else toString v;

  quoteLua = s: "\"${lib.escape ["\"" "\\"] s}\"";

  renderLuaValue = v:
    if builtins.isBool v then (if v then "true" else "false")
    else if builtins.isInt v then toString v
    else if builtins.isFloat v then toString v
    else quoteLua v;

  # ── <servername>.ini ───────────────────────────────────────────────────────
  # Renders an attrset of settings (plus the mods/workshop/join fields) into a
  # `Key=value` file. The mods/WorkshopItems/whitelist/admins lists are computed
  # from the resolved server config and injected here so services.nix/config.nix
  # build the .ini in one place.
  renderIni = { name, settings, mods, workshopItems, whitelist, admins, extra }:
    let
      merge = extra // settings;
      key = n: v: "${n}=${renderIniValue v}";
      # Settings the module always owns (ports, browser listing, mods, access);
      # the user's custom settings ride along via `extra`/`settings` but those
      # keys are placed by the explicit lines below, so drop them from the
      # generic pass.
      owned = [ "defaultPort" "udpPort" "rconPort" "public" "publicName" "maxPlayers" "open" "map" "mods" "workshopItems" "whitelist" "admins" ];
      lines = [
        (key "DefaultPort" merge.defaultPort)
        (key "UDPPort" merge.udpPort)
        (key "RCONPort" merge.rconPort)
        (key "Public" merge.public)
        (key "PublicName" merge.publicName)
        (key "MaxPlayers" merge.maxPlayers)
        (key "Open" merge.open)
        (key "Map" merge.map)
        (key "Mods" (lib.concatStringsSep "," mods))
        (key "WorkshopItems" (lib.concatStringsSep ";" workshopItems))
        (key "Whitelist" (lib.concatStringsSep "," whitelist))
        (key "Users" (lib.concatStringsSep "," admins))
      ];
      extraLines = lib.mapAttrsToList key (lib.removeAttrs settings owned);
    in
    lib.concatStringsSep "\n" (lines ++ extraLines) + "\n";

  # ── <servername>_SandboxVars.lua ───────────────────────────────────────────
  renderSandbox = { settings }:
    let
      body = lib.concatStringsSep ",\n"
        (lib.mapAttrsToList (n: v: "    ${n} = ${renderLuaValue v}") settings);
    in
    "SandboxVars = {\n${body}\n}\n";

in
{
  inherit renderIni renderSandbox;

  # Resolve the effective per-server config by merging:
  #   module defaults  <  the named modpack's defaults  <  inline server values.
  # Returns the fields (name, map, ports, mods, workshopItems, whitelist,
  # admins, settings, sandbox, ...) that the .ini/lua renderers and units need.
  resolveServer = modpacks: name: srv:
    let
      pack =
        if srv.modpack != null then
          (
            modpacks.${srv.modpack} or (throw ''
              my.services.projectZomboid: server ${name} references modpack
              '${srv.modpack}' which does not exist. Define it in
              modules/nixos/projectzomboid-server/modpacks/ or pick a different name.
            '')
          )
        else
          { workshopMods = [ ]; mods = [ ]; defaultSettings = { }; defaultSandbox = { }; };
    in
    {
      name = if srv.name != "" then srv.name else name;
      description = if srv.description != "" then srv.description else "Project Zomboid server: ${name}";
      map = srv.map;
      defaultPort = srv.defaultPort;
      udpPort = srv.udpPort;
      rconPort = srv.rconPort;
      openFirewall = srv.openFirewall;
      autoStart = srv.autoStart;
      restart = srv.restart;
      jvmOpts = srv.jvmOpts;
      hardware = srv.hardware;
      extraServiceConfig = srv.extraServiceConfig;
      opencodeWeb = srv.opencodeWeb;

      # All Workshop item IDs (pack's + server's).
      workshopItems = map (m: m.id) (pack.workshopMods ++ srv.workshopMods);
      # Local mod folder names (pack's + server's).
      mods = pack.mods ++ srv.mods;

      whitelist = srv.whitelist;
      admins = srv.admins;

      # .ini settings = pack defaults overlaid by inline server settings, then the
      # port/map/maxplayers/public/etc. the module owns.
      settings = lib.recursiveUpdate
        (pack.defaultSettings // {
          inherit (srv) map defaultPort udpPort rconPort maxPlayers;
          public = if srv.public != null then srv.public else true;
          publicName = if srv.publicName != null then srv.publicName else name;
          open = if srv.open != null then srv.open else true;
        })
        srv.settings;

      # Sandbox = pack defaults overlaid by server inline values.
      sandbox = lib.recursiveUpdate pack.defaultSandbox srv.sandbox;

      passwordFile = srv.passwordFile;
    };
}
