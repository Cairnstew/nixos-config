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
    jvmOpts = "-Xmx6G -Xms4G";
    port = 25565;
    autoStart = true;
    # Preserve the world from the old `test` server dir (renamed to dragentech).
    migrateFrom = "/mnt/data/minecraft/test";

    serverProperties = {
      motd = "A DragonTech Server";
      max-players = 4;
      white-list = false;
    };
    whitelist = { };
    operators = { };
  };
}
