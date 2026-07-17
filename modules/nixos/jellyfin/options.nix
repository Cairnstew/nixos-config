{ lib, pkgs, ... }:
{
  options.my.services.jellyfin = {
    enable = lib.mkEnableOption "Jellyfin media server";

    package = lib.mkPackageOption pkgs "jellyfin" { };

    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/jellyfin";
      description = "Data directory for Jellyfin";
    };

    configDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/jellyfin/config";
      description = "Configuration directory for Jellyfin";
    };

    cacheDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/cache/jellyfin";
      description = "Cache directory for Jellyfin";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "jellyfin";
      description = "User account under which Jellyfin runs";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "jellyfin";
      description = "Group under which Jellyfin runs";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open the firewall for the Jellyfin web interface";
    };

    mediaDirs = lib.mkOption {
      type = lib.types.listOf lib.types.path;
      default = [ ];
      example = [ "/mnt/media/movies" "/mnt/media/tv" ];
      description = "Media directories to grant Jellyfin read access to";
    };
  };
}
