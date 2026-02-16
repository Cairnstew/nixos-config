{ config, lib, pkgs, ... }:

let
  cfg = config.my.services.docker;
in
{
  ######################
  # Options
  ######################
  options.my.services.docker = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Docker and related system configuration.";
    };

    users = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Users to add to the docker group.";
    };
  };

  ######################
  # Implementation
  ######################
  config = lib.mkIf cfg.enable {
    virtualisation.docker = {
      enable = true;
      enableOnBoot = true;
    };

    users.users = lib.genAttrs cfg.users (_: {
      extraGroups = [ "docker" ];
    });
  };
}
