{ config, lib, pkgs, ... }:
let
  cfg = config.my.services.sillytavern;
  homeDir = "/var/lib/sillytavern";
  stDataDir = "${homeDir}/.local/share/SillyTavern";
  stUserDir = "${stDataDir}/data/default-user";

  ollamaProfileId = "a1b2c3d4-e5f6-7890-abcd-ef1234567890";
  ollamaUrl = "http://${cfg.ollama.host}:${toString cfg.ollama.port}";

  ollamaSettingsJson = builtins.toJSON {
    power_user = {
      servers = [{ label = "ollama"; url = "${ollamaUrl}/"; }];
    };
    extension_settings = {
      connectionManager = {
        selectedProfile = ollamaProfileId;
        profiles = [{
          id = ollamaProfileId;
          mode = "tc";
          exclude = [ ];
          api = "ollama";
          preset = "Default";
          "api-url" = ollamaUrl;
          model = cfg.ollama.model;
          sysprompt = "Neutral - Chat";
          "sysprompt-state" = "true";
          context = "Default";
          "instruct-state" = "false";
          tokenizer = "best_match";
          "stop-strings" = "";
          "start-reply-with" = "";
          "reasoning-template" = "Think XML";
          name = "ollama ${cfg.ollama.model} - Default";
        }];
      };
    };
  };

  seedScript = pkgs.writeShellScript "sillytavern-seed" ''
    set -euo pipefail
    mkdir -p "${stDataDir}"
    mkdir -p "${stUserDir}"

    ${cfg.presets.activationScript}

    SETTINGS="${stUserDir}/settings.json"
    if [ ! -f "$SETTINGS" ]; then
      ${if cfg.ollama.enable then ''
        cp ${pkgs.writeText "ollama-settings.json" ollamaSettingsJson} "$SETTINGS"
        echo "sillytavern: seeded settings.json with Ollama connection profile"
      '' else ''
        echo "{}" > "$SETTINGS"
      ''}
    fi

    chown -R ${cfg.user}:${cfg.group} "${homeDir}"
  '';
in
{
  config = lib.mkIf cfg.enable {
    systemd.services.sillytavern = {
      description = "SillyTavern LLM Frontend";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ] ++ lib.optional cfg.ollama.enable "ollama.service";
      wants = lib.optional cfg.ollama.enable "ollama.service";

      environment = {
        HOME = homeDir;
        XDG_DATA_HOME = "${homeDir}/.local/share";
        SILLYTAVERN_PORT = toString cfg.port;
        SILLYTAVERN_LISTEN = lib.boolToString cfg.listen;
        SILLYTAVERN_WHITELISTMODE = lib.boolToString cfg.whitelistMode;
        SILLYTAVERN_WHITELIST = builtins.toJSON cfg.whitelistAddresses;
        SILLYTAVERN_BASICAUTHMODE = lib.boolToString cfg.basicAuthMode;
        SILLYTAVERN_BASICAUTHUSER__USERNAME = cfg.basicAuthUser;
        SILLYTAVERN_BASICAUTHUSER__PASSWORD = cfg.basicAuthPassword;
        SILLYTAVERN_BROWSERLAUNCH__ENABLED = "false";
        SILLYTAVERN_SECURITYOVERRIDE = lib.boolToString (
          cfg.listen && !cfg.whitelistMode && !cfg.basicAuthMode
        );
      } // lib.optionalAttrs (cfg.listenAddressIPv4 != null) {
        SILLYTAVERN_LISTENADDRESS__IPV4 = cfg.listenAddressIPv4;
      } // lib.optionalAttrs (cfg.listenAddressIPv6 != null) {
        SILLYTAVERN_LISTENADDRESS__IPV6 = cfg.listenAddressIPv6;
      };

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        WorkingDirectory = homeDir;
        StateDirectory = "sillytavern";
        StateDirectoryMode = "0750";
        ExecStartPre = "+${seedScript}";
        ExecStart = "${lib.getExe cfg.package}";
        Restart = "on-failure";
        RestartSec = "5s";
        NoNewPrivileges = true;
        PrivateTmp = true;
        PrivateDevices = true;
        ProtectHome = false;
        ProtectSystem = "strict";
        ReadWritePaths = [ homeDir ];
        CapabilityBoundingSet = [ "CAP_CHOWN" "CAP_DAC_OVERRIDE" ];
        LockPersonality = true;
        MemoryDenyWriteExecute = false;
        RestrictNamespaces = true;
        RestrictRealtime = true;
      };
    };
  };
}
