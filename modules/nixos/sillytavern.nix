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

    whitelistMode = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enables whitelist mode, restricting access to whitelisted IPs only.";
    };

    whitelistAddresses = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      example = [ "192.168.1.10" "10.0.0.5" ];
      description = "IP addresses allowed when whitelistMode is true.";
    };

    # Note: --configPath is ignored by SillyTavern 1.17+ in "global mode".
    # Config is always read from $HOME/.local/share/SillyTavern/config.yaml.
    # This option is kept for documentation/future use but has no effect at runtime.
    configFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      example = "/etc/sillytavern/config.yaml";
      description = ''
        Path to the SillyTavern configuration file.
        NOTE: SillyTavern 1.17+ ignores --configPath in global mode and always
        uses $HOME/.local/share/SillyTavern/config.yaml. If null, the module
        generates that file via a seed script on first run.
      '';
    };

    ollama = {
      enable = lib.mkEnableOption "automatic Ollama API configuration";

      host = lib.mkOption {
        type = lib.types.str;
        default = "127.0.0.1";
        description = "Hostname or IP address of the Ollama instance.";
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = 11434;
        description = "Port of the Ollama instance.";
      };

      model = lib.mkOption {
        type = lib.types.str;
        default = "";
        example = "llama3.2";
        description = "Default Ollama model to pre-select. Must already be pulled in Ollama.";
      };
    };
  };

  config =
    let
      # SillyTavern 1.17+ always uses $HOME/.local/share/SillyTavern/ regardless
      # of --configPath, so we point the home dir here and let XDG do the rest.
      homeDir = "/var/lib/sillytavern";
      stDataDir = "${homeDir}/.local/share/SillyTavern";
      stUserDir = "${stDataDir}/data/default-user";

      # config.yaml written into the XDG data dir on first run.
      configYaml = lib.generators.toYAML { } (
        {
          port = cfg.port;
          listen = cfg.listen;
          whitelistMode = cfg.whitelistMode;
          whitelist = cfg.whitelistAddresses;
        }
        // lib.optionalAttrs (cfg.listenAddressIPv4 != null && !cfg.listen) {
          listenAddressIPv4 = cfg.listenAddressIPv4;
        }
        // lib.optionalAttrs (cfg.listenAddressIPv6 != null && !cfg.listen) {
          listenAddressIPv6 = cfg.listenAddressIPv6;
        }
      );

      ollamaSettingsJson = builtins.toJSON {
        main_api = "ollama";
        api_server = "http://${cfg.ollama.host}:${toString cfg.ollama.port}";
        ollama = {
          server_url = "http://${cfg.ollama.host}:${toString cfg.ollama.port}";
          selected_model = cfg.ollama.model;
        };
      };

      # Runs as root (+) before the service starts.
      # Seeds config.yaml and optionally settings.json on first run only.
      seedScript = pkgs.writeShellScript "sillytavern-seed" ''
        set -euo pipefail

        mkdir -p "${stDataDir}"
        mkdir -p "${stUserDir}"

        # Seed config.yaml if absent
        if [ ! -f "${stDataDir}/config.yaml" ]; then
          printf '%s' '${configYaml}' > "${stDataDir}/config.yaml"
          echo "sillytavern: seeded config.yaml (port=${toString cfg.port}, listen=${lib.boolToString cfg.listen})"
        fi

        ${lib.optionalString cfg.ollama.enable ''
          # Seed settings.json with Ollama config if absent
          if [ ! -f "${stUserDir}/settings.json" ]; then
            printf '%s' '${ollamaSettingsJson}' > "${stUserDir}/settings.json"
            echo "sillytavern: seeded settings.json with Ollama config"
            echo "  url  : http://${cfg.ollama.host}:${toString cfg.ollama.port}"
            echo "  model: ${cfg.ollama.model}"
          fi
        ''}

        # Fix ownership so the service user can write to its data dir
        chown -R ${cfg.user}:${cfg.group} "${homeDir}"
      '';
    in
    lib.mkIf cfg.enable {
      users.users = lib.mkIf (cfg.user == "sillytavern") {
        sillytavern = {
          isSystemUser = true;
          group = cfg.group;
          description = "SillyTavern service user";
          home = homeDir;
          createHome = true;
        };
      };

      users.groups = lib.mkIf (cfg.group == "sillytavern") {
        sillytavern = { };
      };

      systemd.services.sillytavern = {
        description = "SillyTavern LLM Frontend";
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" ]
          ++ lib.optional cfg.ollama.enable "ollama.service";
        wants = lib.optional cfg.ollama.enable "ollama.service";

        environment = {
          # Make XDG_DATA_HOME explicit so SillyTavern finds its data dir
          # even when run as a system service without a proper login session.
          HOME = homeDir;
          XDG_DATA_HOME = "${homeDir}/.local/share";
        };

        serviceConfig = {
          Type = "simple";
          User = cfg.user;
          Group = cfg.group;
          WorkingDirectory = homeDir;
          StateDirectory = "sillytavern";
          StateDirectoryMode = "0750";

          # Seed config/settings on first run; no-op on subsequent starts.
          ExecStartPre = "+${seedScript}";

          ExecStart = "${lib.getExe cfg.package}";

          Restart = "on-failure";
          RestartSec = "5s";

          # Hardening
          NoNewPrivileges = true;
          PrivateTmp = true;
          PrivateDevices = true;
          ProtectHome = false; # needs access to homeDir
          ProtectSystem = "strict";
          ReadWritePaths = [ homeDir ];
          CapabilityBoundingSet = [ "CAP_CHOWN" "CAP_DAC_OVERRIDE" ];
          LockPersonality = true;
          MemoryDenyWriteExecute = false; # V8 JIT requires W+X pages
          RestrictNamespaces = true;
          RestrictRealtime = true;
          # SystemCallFilter omitted — SillyTavern uses fs.chown() and other
          # syscalls that conflict with allowlist-based filtering
        };
      };
    };
}
