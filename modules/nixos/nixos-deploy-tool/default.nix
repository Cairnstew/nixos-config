{ config, lib, pkgs, flake, ... }:
let
  cfg = config.my.services.nixos-deploy-tool;
  upstreamSettings = config.services.nixos-deploy-tool.settings or { };
in
{
  imports = [
    flake.inputs.nixos-deploy-tool.nixosModules.default
  ];

  options.my.services.nixos-deploy-tool = {
    enable = lib.mkEnableOption "nixos-deploy-tool service + CLI integration" // {
      description = ''
        Enable the nixos-deploy-tool systemd service and CLI integration.
        Auto-wires paths to agenix-manager, nixos-anywhere, and age from
        existing system configuration.
      '';
    };

    settings = lib.mkOption {
      type = lib.types.submodule {
        freeformType = lib.types.attrsOf lib.types.raw;
        options = {
          flakeRoot = lib.mkOption {
            type = lib.types.str;
            default = "/etc/nixos";
            description = "Path to the flake root directory";
          };

          logLevel = lib.mkOption {
            type = lib.types.enum [ "debug" "info" "warn" "error" ];
            default = "info";
            description = "Log verbosity level";
          };

          liveIsoUser = lib.mkOption {
            type = lib.types.str;
            default = "nixos";
            description = "Default SSH user for live ISOs";
          };

          ageBin = lib.mkOption {
            type = lib.types.str;
            default = "${lib.getBin pkgs.age}/bin/age";
            defaultText = lib.literalExpression ''"${pkgs.age}/bin/age"'';
            description = "Path to the age binary";
          };

          agenixManagerBin = lib.mkOption {
            type = lib.types.str;
            default = "${lib.getBin config.agenixManager.package}/bin/agenix-manager";
            defaultText = lib.literalExpression ''"${config.agenixManager.package}/bin/agenix-manager"'';
            description = "Path to the agenix-manager binary";
          };

          nixosAnywhereBin = lib.mkOption {
            type = lib.types.str;
            default = "${lib.getBin pkgs.nixos-anywhere}/bin/nixos-anywhere";
            defaultText = lib.literalExpression ''"${pkgs.nixos-anywhere}/bin/nixos-anywhere"'';
            description = "Path to the nixos-anywhere binary";
          };
        };
      };
      default = { };
      description = ''
        Settings forwarded to services.nixos-deploy-tool.settings.
        Defaults are auto-wired from the system configuration.
      '';
    };

    tailscaleOAuth = {
      enable = lib.mkEnableOption "Tailscale OAuth integration" // {
        description = ''
          Configure Tailscale OAuth credentials for nixos-deploy-tool.
          When enabled, wires clientId and clientSecretFile from agenix secrets.
        '';
      };

      clientId = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Tailscale OAuth client ID";
      };

      clientSecretFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = ''
          Path to the Tailscale OAuth client secret file.
          Typically an agenix-decrypted path like /run/agenix/tailscale-oauth-secret.
        '';
      };
    };

    environment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Extra environment variables passed to the nixos-deploy-tool systemd service";
    };
  };

  config = lib.mkIf cfg.enable {
    services.nixos-deploy-tool = {
      enable = true;

      settings = lib.recursiveUpdate {
        flakeRoot = cfg.settings.flakeRoot;
        logLevel = cfg.settings.logLevel;
        liveIsoUser = cfg.settings.liveIsoUser;
        ageBin = cfg.settings.ageBin;
        agenixManagerBin = cfg.settings.agenixManagerBin;
        nixosAnywhereBin = cfg.settings.nixosAnywhereBin;
      } (lib.optionalAttrs cfg.tailscaleOAuth.enable {
        tailscaleOAuth = {
          clientId = cfg.tailscaleOAuth.clientId;
          clientSecretFile = toString cfg.tailscaleOAuth.clientSecretFile;
        };
      });

      environment = cfg.environment;
    };
  };
}
