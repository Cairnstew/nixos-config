# modules/nixos/projectzomboid-server/servers/knox.nix
# Example server: "knox" — a Vanilla+ PZ server in Muldraugh. Disabled by
# default; enable from a host config or profile, e.g.:
#   my.services.projectZomboid.servers.knox.enable = true;
{ lib, ... }:
{
  my.services.projectZomboid.servers.knox = {
    enable = lib.mkDefault false;

    name = "knox";           # -> Zomboid/Server/knox.ini, Saves/Multiplayer/knox
    description = "A Vanilla+ Project Zomboid server hosted from NixOS";

    # Reuse the cleaned-up vanilla-plus modpack (its workshop items, plus its
    # defaultSettings/defaultSandbox). We add one more Workshop mod inline.
    modpack = "vanilla-plus";
    workshopMods = [
      { id = "2705255374"; title = "10 Years Later"; }
    ];

    map = "Muldraugh, KY";
    defaultPort = 16261;     # UDP
    udpPort = 16262;         # UDP (direct connection)
    rconPort = 27015;        # TCP (RCON) — only open in the firewall if you need it
    openFirewall = true;
    public = true;
    publicName = "Knox County Vanilla+";

    maxPlayers = 16;

    # Whitelisted clients / admins (comma lists).
    open = true;             # anyone may join
    whitelist = [ "seanc" ];
    admins = [ "seanc" ];

    # Join password from an agenix secret.
    passwordFile = null;

    # Server .ini overrides (win over the modpack's defaultSettings).
    settings = {
      PVP = true;
      GlobalChat = true;
      MaxPlayers = 16;
      PauseEmpty = true;
      AnnounceDeath = true;
      DisableSafehouseWhenOwnerConnected = true;
      ShowFirstAndLastName = false;
    };

    # Sandbox overrides (win over the modpack's defaultSandbox).
    sandbox = {
      Zombies = 4;           # Normal — a bit harder than the pack default
      MultiHitZombies = true;
      StarterKit = true;
    };

    # Heap sized for a modest host; the PZ server is a Java process.
    jvmOpts = "-Xmx6G -Xms3G -XX:+UseZGC -XX:-CreateCoredumpOnCrash";

    # Resource caps so a runaway server can't OOM the host.
    hardware = {
      memoryHigh = "7G";
      memoryMax = "10G";
      memorySwapMax = "2G";
      nice = 5;
    };
  };
}
