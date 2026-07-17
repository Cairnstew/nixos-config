{ lib, pkgs, ... }:
{
  options.my.services.radarr = {
    enable = lib.mkEnableOption "Radarr movie download and management";

    package = lib.mkPackageOption pkgs "radarr" { };

    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/radarr";
      description = "Data directory for Radarr";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "radarr";
      description = "User account under which Radarr runs";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "radarr";
      description = "Group under which Radarr runs";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open the firewall for the Radarr web interface";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 7878;
      description = "Port for the Radarr web interface";
    };

    disableAnalytics = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Disable anonymous usage data collection";
    };
  };
}
