# modules/nixos/projectzomboid-server/servers/knox.nix
# Server: "knox" — a Vanilla+ PZ server in Muldraugh. Disabled by default;
# enable from a host config or profile, e.g.:
#   services.project-zomboid-servers.servers.knox.enable = true;
#
# Options are the upstream module's (services.project-zomboid-servers.*) — see
# the upstream docs/options.md, which its own CI keeps complete.
{ config, lib, ... }:
{
  services.project-zomboid-servers.servers.knox = {
    enable = lib.mkDefault false;

    name = "knox"; # -> Zomboid/Server/knox.ini, Saves/Multiplayer/knox
    description = "A Vanilla+ Project Zomboid server hosted from NixOS";

    # Upstream's catalogue pack, wired in by ../config.nix. It is a superset of
    # the pack this repo used to define locally: same four Brita's/expansion
    # mods plus iTrackify and Ched605's Fully Upgradable Tooltips, and it sets
    # DoLuaChecksum=false, which Build 42 otherwise uses to false-positive on
    # Linux and block clients from joining.
    modpack = "vanilla-plus";

    # Inline workshopMods ADD to the pack's list, they do not replace it.
    workshopMods = [
      { id = "2705255374"; title = "10 Years Later"; }
    ];

    # Map= is DERIVED from the maps the installed mods actually ship, with the
    # vanilla base map ordered last. This module used to pin
    # map = "Muldraugh, KY"; the result is identical today (no vanilla-plus mod
    # ships a map) but derivation keeps working if a map mod is added later. Set
    # `map` explicitly to pin the list and switch derivation off.
    baseMap = "Muldraugh, KY";

    defaultPort = 16261; # UDP, game
    udpPort = 16262; # UDP, direct connection — PZ binds two per instance
    # 27016, not the 27015 this used to use: 27015 is Minecraft's default RCON
    # port and this repo runs a Minecraft server module on the same host.
    # Upstream's docs recommend the same. 0 disables RCON.
    rconPort = 27016;
    openFirewall = true;
    public = true;
    publicName = "Knox County Vanilla+";

    maxPlayers = 16;

    open = true; # anyone may join

    # ── Access control ──────────────────────────────────────────────────────
    # Build 42 has no .ini key for the admin login: it is a row in
    # Zomboid/db/knox.db, written only through the -adminusername /
    # -adminpassword pair. This config previously set `admins = [ "seanc" ]`,
    # which the upstream module deliberately no longer renders (Users= is not a
    # documented Build 42 key, so it produced a config that looked authoritative
    # and did nothing). adminAccount is the supported replacement, and the
    # password comes from an agenix secret — never inline, and never in `ps`
    # beyond the process lifetime.
    #
    # `whitelist` / `admins` remain available but are Build 41 only
    # (compatibility.build41). They are omitted here because `open = true`
    # makes the whitelist inert anyway.
    adminAccount = {
      username = "seanc";
      passwordFile = config.age.secrets.pz-admin-password.path;
    };

    # Server .ini overrides (win over the modpack's defaultSettings).
    # MaxPlayers is set by the dedicated option above, not here.
    settings = {
      GlobalChat = true;
      AnnounceDeath = true;
      DisableSafehouseWhenOwnerConnected = true;
      ShowFirstAndLastName = false;
    };

    # Sandbox overrides (win over the modpack's defaultSandbox).
    sandbox = {
      Zombies = 4; # Normal — a bit harder than the pack default (High)
      MultiHitZombies = true;
      StarterKit = true;
    };

    # Heap sized for a modest host; the PZ server is a Java process.
    jvmOpts = "-Xmx6G -Xms3G -XX:+UseZGC -XX:-CreateCoredumpOnCrash";

    # Resource caps so a runaway server can't OOM the host. memoryMax must stay
    # above jvmOpts' -Xmx or the JVM gets killed before it fills the heap.
    hardware = {
      memoryHigh = "7G";
      memoryMax = "10G";
      memorySwapMax = "2G";
      nice = 5;
    };
  };
}
