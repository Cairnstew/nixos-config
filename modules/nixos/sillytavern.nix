{ config, lib, pkgs, ... }:

let
  cfg = config.my.services.sillytavern;
in
{
  options.my.services.sillytavern = {
    enable = lib.mkEnableOption "sillytavern";

    package = lib.mkPackageOption pkgs "sillytavern" { };

    user = lib.mkOption {
      type = lib.types.str;
      default = "sillytavern";
      description = "User account under which the web-application runs.";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "sillytavern";
      description = "Group account under which the web-application runs.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8000;
      description = "Port on which SillyTavern will listen.";
    };

    listen = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to listen on all network interfaces.";
    };

    listenAddressIPv4 = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "127.0.0.1";
      description = "Specific IPv4 address to listen on. Ignored if listen is true.";
    };

    listenAddressIPv6 = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "::1";
      description = "Specific IPv6 address to listen on. Ignored if listen is true.";
    };

    whitelist = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enables whitelist mode, restricting access to whitelisted IPs only.";
    };

    configFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      example = "/etc/sillytavern/config.yaml";
      description = "Path to the SillyTavern configuration file. If null, a config is generated from the module options.";
    };
  };

  config = lib.mkIf cfg.enable {
    users.users = lib.mkIf (cfg.user == "sillytavern") {
      sillytavern = {
        isSystemUser = true;
        group = cfg.group;
        description = "SillyTavern service user";
        home = "/var/lib/sillytavern";
        createHome = true;
      };
    };

    users.groups = lib.mkIf (cfg.group == "sillytavern") {
      sillytavern = { };
    };

    environment.etc."sillytavern/config.yaml" = lib.mkIf (cfg.configFile == null) {
      text = lib.generators.toYAML { } {
        port = cfg.port;
        listen = cfg.listen;
        whitelist = cfg.whitelist;
      } + lib.optionalString (cfg.listenAddressIPv4 != null && !cfg.listen) ''
        listenAddressIPv4: ${cfg.listenAddressIPv4}
      '' + lib.optionalString (cfg.listenAddressIPv6 != null && !cfg.listen) ''
        listenAddressIPv6: ${cfg.listenAddressIPv6}
      '';
      user = cfg.user;
      group = cfg.group;
      mode = "0640";
    };

    systemd.services.sillytavern = {
      description = "SillyTavern LLM Frontend";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        WorkingDirectory = "/var/lib/sillytavern";
        StateDirectory = "sillytavern";
        StateDirectoryMode = "0750";

        ExecStart =
          let
            configArg =
              if cfg.configFile != null
              then "--configPath ${cfg.configFile}"
              else "--configPath /etc/sillytavern/config.yaml";
          in
          "${lib.getExe cfg.package} ${configArg}";

        Restart = "on-failure";
        RestartSec = "5s";

        # Hardening
        NoNewPrivileges = true;
        PrivateTmp = true;
        PrivateDevices = true;
        ProtectHome = true;
        ProtectSystem = "strict";
        ReadWritePaths = [ "/var/lib/sillytavern" ];
        CapabilityBoundingSet = "";
        LockPersonality = true;
        MemoryDenyWriteExecute = true;
        RestrictNamespaces = true;
        RestrictRealtime = true;
        SystemCallFilter = [ "@system-service" "~@privileged" ];
      };
    };
  };
}
