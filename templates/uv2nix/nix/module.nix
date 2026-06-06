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

    settings = lib.mkOption {
      type = lib.types.submodule {
        options = {
          logLevel = lib.mkOption {
            type = lib.types.enum [ "debug" "info" "warn" "error" ];
            default = "info";
            description = "Log verbosity level";
          };

          extraArgs = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = "Extra CLI arguments passed to the binary";
          };
        };
      };
      default = { };
      description = "Runtime configuration written to /etc/uv2nix-template/config.json";
    };

    environment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Environment variables passed to the service";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.etc."uv2nix-template/config.json" = {
      text = builtins.toJSON cfg.settings;
      mode = "0444";
    };

    systemd.services.uv2nix-template = {
      description = "uv2nix-template";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      serviceConfig = {
        Type = "simple";
        ExecStart = lib.concatStringsSep " " (
          [ "${cfg.package}/bin/uv2nix-template" ] ++ cfg.settings.extraArgs
        );
        Restart = "on-failure";
        RestartSec = "5s";
        Environment = cfg.environment;
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        RestartTriggers = [ config.environment.etc."uv2nix-template/config.json".source ];
      };
    };
  };

}
