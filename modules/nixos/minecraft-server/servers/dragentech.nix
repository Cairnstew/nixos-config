# modules/nixos/minecraft-server/servers/dragentech.nix
# DragonTech NeoForge server (DragonTech packwiz pack). Every server in this
# folder is disabled by default — opt in from a host config or a profile, e.g.:
#   my.services.minecraftServer.servers.dragentech.enable = true;
#   my.profiles.gaming.minecraftServers = [ "dragentech" ];
{ lib, pkgs, ... }:
{
  my.services.minecraftServer.servers.dragentech = {
    enable = lib.mkDefault false;

    package = pkgs.neoforgeServers.neoforge-1_21_1-21_1_238; # matches DragonTech pack.toml
    packwiz = ../modpacks/DragonTech;
    # Heap sized for the server host (15Gi RAM total, shared with other
    # services — see hardware caps below). Modded NeoForge wants a big heap but
    # the OS + other units need headroom; 5G heap + 3G start is the balance.
    jvmOpts = "-Xmx5G -Xms3G";
    port = 25565;
    autoStart = true;
    # Preserve the world from the old `test` server dir (renamed to dragentech).
    migrateFrom = "/mnt/data/minecraft/test";

    # Resource caps so a runaway server can't OOM the host (which also runs
    # opencode-web, backup, monitoring, etc.). Soft throttle at 7G, hard cap at
    # 10G, swap capped at 2G to avoid thrashing; server runs at slightly lower
    # scheduling priority than interactive services.
    hardware = {
      memoryHigh = "7G";
      memoryMax = "10G";
      memorySwapMax = "2G";
      nice = 5;
    };

    serverProperties = {
      motd = "A DragonTech Server";
      max-players = 4;
      white-list = false;
    };
    whitelist = { };
    operators = { };
  };
}
