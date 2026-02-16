{ lib, config, pkgs, ... }:

let
  cfg = config.my.system.location;
in
{
  options.my.system.location = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable system timezone and geographic location";
    };

    timeZone = lib.mkOption {
      type = lib.types.str;
      default = "GB";
      description = "System time zone";
    };

    latitude = lib.mkOption {
      type = lib.types.float;
      default = 55.8617;
      description = "System latitude for location-based services";
    };

    longitude = lib.mkOption {
      type = lib.types.float;
      default = 4.2583;
      description = "System longitude for location-based services";
    };
  };

  config = lib.mkIf cfg.enable {
    time.timeZone = cfg.timeZone;

    location = {
      latitude = cfg.latitude;
      longitude = cfg.longitude;
    };
  };
}
