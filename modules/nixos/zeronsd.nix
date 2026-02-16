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
      default = "home";
      description = "DNS domain served by ZeroNSD.";
    };

    tokenFile = lib.mkOption {
      type = lib.types.path;
      description = "Path to ZeroNSD ZeroTier Central API token file.";
    };

    nameserver = lib.mkOption {
      type = lib.types.str;
      default = "192.168.191.168";
      description = "Nameserver address provided by ZeroNSD.";
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
    networking.search = [ "${cfg.domain}.arpa" ];

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
        ExecStart =
          "${pkgs.zeronsd}/bin/zeronsd start ${cfg.zerotierNetwork}"
          + " -d ${cfg.domain}"
          + " -t ${cfg.tokenFile}"
          + " -w -v";

        Restart = "on-failure";
        RestartSec = "10s";

        Environment =
          "ZEROTIER_CENTRAL_TOKEN_FILE=${cfg.tokenFile}";

        User = "zeronsd";
        Group = "zeronsd";

        RuntimeDirectory = "zeronsd";

        AmbientCapabilities = [ "CAP_NET_BIND_SERVICE" ];
        CapabilityBoundingSet = [ "CAP_NET_BIND_SERVICE" ];

        StandardOutput = "journal";
        StandardError = "journal";
      };
    };

    #### Safety checks ####
    assertions = [
      {
        assertion = cfg.zerotierNetwork != "";
        message = "my.services.zeronsd.enable requires zerotierNetwork to be set";
      }
    ];
  };
}
