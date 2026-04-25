{ config, lib, pkgs, ... }:

let
  cfg = config.my.services.sillytavern;

  # Helper: list all .json files in a directory path (must be a store path or /nix/store path)
  jsonFilesIn = dir:
    lib.optionals (dir != null && builtins.pathExists dir)
      (map (f: dir + "/${f}")
        (lib.filter (f: lib.hasSuffix ".json" f)
          (builtins.attrNames (builtins.readDir dir))));

  moduleDir = builtins.dirOf __curPos.file;
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
      default = [ "127.0.0.1" "::1" ];
      example = [ "192.168.1.10" "10.0.0.5" ];
      description = "IP addresses allowed when whitelistMode is true.";
    };

    basicAuthMode = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable basic authentication.";
    };

    basicAuthUser = lib.mkOption {
      type = lib.types.str;
      default = "user";
      description = "Basic auth username.";
    };

    basicAuthPassword = lib.mkOption {
      type = lib.types.str;
      default = "password";
      description = "Basic auth password.";
    };

    # -------------------------------------------------------------------------
    # Preset directories
    #
    # Each option takes a path to a directory of .json files.
    # By default the module looks for subdirectories next to itself:
    #
    #   sillytavern/
    #     default.nix
    #     presets/
    #       instruct/       ← sillytavern/presets/instruct/
    #       context/        ← sillytavern/presets/context/
    #       sysprompt/      ← sillytavern/presets/sysprompt/
    #       textgen/        ← sillytavern/presets/textgen/
    #
    # Any .json files found are copied into the corresponding
    # data/default-user/ subdirectory and immediately available in the UI.
    # -------------------------------------------------------------------------

    presets = {
      instruct = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default =
          let p = moduleDir + "/presets/instruct";
          in if builtins.pathExists p then p else null;
        description = "Directory of instruct template JSON files → data/default-user/instruct/";
      };

      context = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default =
          let p = moduleDir + "/presets/context";
          in if builtins.pathExists p then p else null;
        description = "Directory of context template JSON files → data/default-user/context/";
      };

      sysprompt = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default =
          let p = moduleDir + "/presets/sysprompt";
          in if builtins.pathExists p then p else null;
        description = "Directory of system prompt JSON files → data/default-user/sysprompt/";
      };

      textgen = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default =
          let p = moduleDir + "/presets/textgen";
          in if builtins.pathExists p then p else null;
        description = "Directory of text completion sampler preset JSON files → data/default-user/TextGen Settings/";
      };
    };

    # -------------------------------------------------------------------------
    # Ollama
    # -------------------------------------------------------------------------

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
              exclude = [];
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

      # Generate a shell fragment that copies all .json files from a nix store
      # path into a target directory, without overwriting existing files.
      copyPresetsFragment = srcDir: destDir:
        let files = jsonFilesIn srcDir;
        in lib.optionalString (files != []) ''
          mkdir -p "${stUserDir}/${destDir}"
          ${lib.concatMapStrings (f: ''
            DEST="${stUserDir}/${destDir}/$(basename "${toString f}")"
            if [ ! -f "$DEST" ]; then
              cp "${f}" "$DEST"
              echo "sillytavern: installed preset $(basename "${toString f}") → ${destDir}/"
            fi
          '') files}
        '';

      seedScript = pkgs.writeShellScript "sillytavern-seed" ''
        set -euo pipefail
        mkdir -p "${stDataDir}"
        mkdir -p "${stUserDir}"

        # ---- Preset files (always synced, never overwrite) ------------------
        ${copyPresetsFragment cfg.presets.instruct  "instruct"}
        ${copyPresetsFragment cfg.presets.context   "context"}
        ${copyPresetsFragment cfg.presets.sysprompt "sysprompt"}
        ${copyPresetsFragment cfg.presets.textgen   "TextGen Settings"}

        # ---- settings.json (only written once) ------------------------------
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
