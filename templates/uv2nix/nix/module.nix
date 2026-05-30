{ config, lib, pkgs, ... }:

let
  cfg = config.services.uv2nix-template;
in

{

  options.services.uv2nix-template = {
    enable = lib.mkEnableOption "uv2nix-template service";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.uv2nix-template;
      defaultText = lib.literalExpression "pkgs.uv2nix-template";
      description = "Package to use as the systemd service binary";
    };

    environment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Environment variables passed to the service";
    };

    extraArguments = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Extra CLI arguments passed to the binary";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.uv2nix-template = {
      description = "uv2nix-template";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      serviceConfig = {
        Type = "simple";
        ExecStart = "${cfg.package}/bin/uv2nix-template${lib.optionalString (cfg.extraArguments != [ ]) " ${lib.escapeShellArgs cfg.extraArguments}"}";
        Restart = "on-failure";
        RestartSec = "5s";
        Environment = cfg.environment;
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
      };
    };
  };

}
