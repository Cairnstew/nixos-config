{ lib, pkgs, ... }:
{
  options.my.services.sonarr = {
    enable = lib.mkEnableOption "Sonarr TV show manager";

    package = lib.mkPackageOption pkgs "sonarr" { };

    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/sonarr";
      description = "Data directory for Sonarr";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "sonarr";
      description = "User account under which Sonarr runs";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "sonarr";
      description = "Group under which Sonarr runs";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open the firewall for the Sonarr web interface";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8989;
      description = "Port for the Sonarr web interface";
    };

    disableAnalytics = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Disable anonymous usage data collection";
    };
  };
}
