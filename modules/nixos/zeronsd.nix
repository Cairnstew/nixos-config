{ config, lib, pkgs, ... }:
let
  cfg = config.my.services.zeronsd;
in
{
  options.my.services.zeronsd = {
    enable = lib.mkEnableOption "ZeroNSD service for ZeroTier";

    zerotierNetwork = lib.mkOption {
      type = lib.types.str;
      example = "8056c2e21c000001";
      description = "ZeroTier network ID to run ZeroNSD against.";
    };

    domain = lib.mkOption {
      type = lib.types.str;
      default = "home.arpa";
      example = "home.arpa";
      description = "DNS domain served by ZeroNSD (used as TLD and search domain).";
    };

    tokenFile = lib.mkOption {
      type = lib.types.path;
      example = "/run/secrets/zeronsd_token";
      description = "Path to file containing the ZeroTier Central API token.";
    };

    nameserver = lib.mkOption {
      type = lib.types.str;
      default = "192.168.191.168";
      example = "192.168.191.168";
      description = "IP address of the ZeroNSD nameserver (usually this host's ZeroTier IP).";
    };

    verbose = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable verbose logging for ZeroNSD.";
    };
  };

  config = lib.mkIf cfg.enable {

    #### Base services ####
    services.openssh.enable = lib.mkDefault true;
    services.resolved.enable = lib.mkDefault true;

    #### Packages ####
    environment.systemPackages = [ pkgs.zeronsd ];

    #### Networking ####
    networking.nameservers = [ cfg.nameserver ];
    networking.search = [ cfg.domain ];

    #### System user ####
    users.users.zeronsd = {
      isSystemUser = true;
      description = "ZeroNSD service user";
      group = "zeronsd";
    };
    users.groups.zeronsd = {};

    #### ZeroNSD service ####
    systemd.services."zeronsd-${cfg.zerotierNetwork}" = {
      description = "ZeroNSD for ZeroTier network ${cfg.zerotierNetwork}";
      after = [ "network.target" "zerotierone.service" ];
      wants = [ "zerotierone.service" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "simple";
        ExecStart = lib.concatStringsSep " " ([
          "${pkgs.zeronsd}/bin/zeronsd start"
          "-d ${cfg.domain}"
          "-t ${cfg.tokenFile}"
          "-w"
          cfg.zerotierNetwork
        ] ++ lib.optional cfg.verbose "-v");
        Restart = "on-failure";
        RestartSec = "10s";
        User = "zeronsd";
        Group = "zeronsd";
        RuntimeDirectory = "zeronsd";
        # Allow binding port 53 without running as root
        AmbientCapabilities = [ "CAP_NET_BIND_SERVICE" ];
        CapabilityBoundingSet = [ "CAP_NET_BIND_SERVICE" ];
        # Harden the service
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        # Allow reading the token file from outside RuntimeDirectory
        ReadOnlyPaths = [ cfg.tokenFile ];
        StandardOutput = "journal";
        StandardError = "journal";
      };
    };

    #### Safety checks ####
    assertions = [
      {
        assertion = cfg.zerotierNetwork != "";
        message = "my.services.zeronsd: zerotierNetwork must be set";
      }
      {
        assertion = lib.stringLength cfg.zerotierNetwork == 16;
        message = "my.services.zeronsd: zerotierNetwork should be a 16-character hex string";
      }
    ];
  };
}