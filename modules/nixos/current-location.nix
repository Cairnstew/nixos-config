{ lib, config, pkgs, flake, ... }:

let
  cfg = config.my.system.location;
  # Use flake config location settings if module not explicitly configured
  flakeLocation = flake.config.location or { };
in
{
  options.my.system.location = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable system timezone and geographic location from config.nix";
    };

    timeZone = lib.mkOption {
      type = lib.types.str;
      # Use flake config location.timeZone as default
      default = flakeLocation.timeZone or "Europe/London";
      description = "System time zone (IANA identifier). Defaults to config.location.timeZone.";
    };

    latitude = lib.mkOption {
      type = lib.types.float;
      # Use flake config location.latitude as default
      default = flakeLocation.latitude or 55.8617;
      description = "System latitude for location-based services. Defaults to config.location.latitude.";
    };

    longitude = lib.mkOption {
      type = lib.types.float;
      # Use flake config location.longitude as default
      default = flakeLocation.longitude or (-4.2583);
      description = "System longitude for location-based services. Defaults to config.location.longitude.";
    };
  };

  config = lib.mkIf cfg.enable {
    time.timeZone = cfg.timeZone;

    location = {
      latitude = cfg.latitude;
      longitude = cfg.longitude;
    };

    # Also set system locale if specified in flake config
    i18n.defaultLocale = flakeLocation.defaultLocale or "en_GB.UTF-8";
  };
}
