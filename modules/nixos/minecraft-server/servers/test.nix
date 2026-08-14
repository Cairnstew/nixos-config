# modules/nixos/minecraft-server/servers/test.nix
# Basic NeoForge test server (testModpack packwiz pack). Every server in this folder is disabled by
# default — opt in from a host config or a profile, e.g.:
#   my.services.minecraftServer.servers.test.enable = true;
#   my.profiles.gaming.minecraftServers = [ "test" ];
{ lib, pkgs, ... }:
{
  my.services.minecraftServer.servers.test = {
    enable = lib.mkDefault false;

    package = pkgs.neoforgeServers.neoforge-1_21_1-21_1_238; # matches testModpack pack.toml
    packwiz = ../modpacks/testModpack;
    jvmOpts = "-Xmx6G -Xms4G";
    port = 25565;
    autoStart = true;

    serverProperties = {
      motd = "A NixOS Test Server";
      max-players = 4;
      white-list = false;
    };
    whitelist = { };
    operators = { };
  };
}
