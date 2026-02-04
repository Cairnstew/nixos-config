{ config, pkgs, lib, ... }:
let
  cfg = config.my.programs.thunderbird;
in
{
  options.my.programs.thunderbird = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Mozilla Thunderbird email client";
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.thunderbird;
      description = "The Thunderbird package to install";
    };

    username = lib.mkOption {
      type = lib.types.str;
      default = config.home.username;
      description = "Username for Thunderbird profile";
    };

    email = lib.mkOption {
      type = lib.types.str;
      default = "sean.cairnsst@gmail.com";
      description = "Default email address for Thunderbird configuration";
      example = "user@example.com";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.thunderbird = {
      enable = true;
      package = cfg.package;
      profiles.${cfg.username}.isDefault = true;
    };
  };
}