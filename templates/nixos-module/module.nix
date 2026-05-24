# NixOS module template following my.* namespace conventions
{ config, lib, pkgs, ... }:
let
  cfg = config.my.services.my-service;
in
{
  options.my.services.my-service = {
    enable = lib.mkEnableOption "My Service";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.hello;
      description = "The package to use for my-service";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "my-service";
      description = "User to run my-service as";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8080;
      description = "Port to listen on";
    };
  };

  config = lib.mkIf cfg.enable {
    users.users.''${cfg.user} = {
      isSystemUser = true;
      group = cfg.user;
    };
    users.groups.''${cfg.user} = { };

    systemd.services.my-service = {
      description = "My Service";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      serviceConfig = {
        ExecStart = "''${cfg.package}/bin/hello";
        User = cfg.user;
        Group = cfg.user;
        Restart = "on-failure";
      };
    };
  };
}


