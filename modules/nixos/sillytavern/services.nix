{ config, lib, pkgs, ... }:
let
  cfg = config.my.services.sillytavern;
  vfcfg = cfg.extensions.vectfox;
  homeDir = "/var/lib/sillytavern";
  stDataDir = "${homeDir}/.local/share/SillyTavern";
  stUserDir = "${stDataDir}/data/default-user";

  ollamaUrl = "http://${cfg.ollama.host}:${toString cfg.ollama.port}";

  modelProfileId = tag:
    let h = builtins.hashString "sha256" "sillytavern-${tag}";
    in "${builtins.substring 0 8 h}-${builtins.substring 8 4 h}-${builtins.substring 12 4 h}-${builtins.substring 16 4 h}-${builtins.substring 20 12 h}";

  mkProfile = tag: mcfg: {
    id = modelProfileId tag;
    mode = "tc";
    exclude = [ ];
    api = "ollama";
    preset = mcfg.preset;
    "api-url" = ollamaUrl;
    model = tag;
    sysprompt = mcfg.sysprompt;
    "sysprompt-state" = if mcfg.syspromptState then "true" else "false";
    context = mcfg.context;
    "instruct-state" = if mcfg.instruct != null then "true" else "false";
    tokenizer = mcfg.tokenizer;
    "stop-strings" = "";
    "start-reply-with" = if cfg.presets.reasoning ? ${mcfg.reasoningTemplate} then (cfg.presets.reasoning.${mcfg.reasoningTemplate}).prefix else "";
    "reasoning-template" = mcfg.reasoningTemplate;
    name = "ollama ${tag} - ${mcfg.preset}";
  };

  hasModels = cfg.ollama.enable && cfg.ollama.models != { };

  profiles =
    if hasModels then
      lib.mapAttrsToList mkProfile cfg.ollama.models
    else if cfg.ollama.enable then
      [ (mkProfile cfg.ollama.model {
          preset = "Default";
          sysprompt = "Neutral - Chat";
          syspromptState = true;
          context = "Default";
          instruct = null;
          tokenizer = "best_match";
          reasoningTemplate = "Think XML";
        }) ]
    else
      [ ];

  selectedProfile =
    if profiles != [ ] then
      lib.findFirst (p: p ? "reasoning-template" && p."reasoning-template" == "Deep Think") (lib.head profiles) profiles
    else
      null;

  firstModel = if profiles != [ ] then (lib.head profiles).model else null;

  ollamaSettingsJson = builtins.toJSON {
    api_type = "ollama";
    api_server = ollamaUrl;
    model = if selectedProfile != null then selectedProfile.model else firstModel;
    power_user = {
      always_force_name2 = false;
      instruct = {
        names_behavior = "none";
      };
      user_prompt_bias = "<think>";
      show_user_prompt_bias = true;
      servers = [{ label = "ollama"; url = "${ollamaUrl}/"; }];
    };
    extension_settings = {
      connectionManager = {
        selectedProfile = if selectedProfile != null then selectedProfile.id else "";
        profiles = profiles;
      };
    };
  };

  modelPullCmds = if cfg.ollama.enable then
    lib.concatStringsSep "\n" (lib.mapAttrsToList (tag: _: ''
      echo "sillytavern: pulling model ${tag} via ollama..."
      ${pkgs.docker}/bin/docker exec ollama ollama pull ${lib.escapeShellArg tag} \
        || echo "sillytavern: WARN: failed to pull ${tag}"
    '') cfg.ollama.models)
  else
    "";

  ollamaServiceName =
    if cfg.ollama.enable then
      "${config.my.services.ollama.backend}-ollama.service"
    else
      "";

  personaId = name: let h = builtins.hashString "sha256" "persona-${name}"; in "${builtins.substring 0 8 h}-${builtins.substring 8 4 h}-${builtins.substring 12 4 h}-${builtins.substring 16 4 h}-${builtins.substring 20 12 h}";

  personasSettingsJson = lib.mkIf (cfg.personas != { }) (builtins.toJSON {
    power_user = {
      personas = lib.mapAttrs' (name: pcfg:
        lib.nameValuePair (personaId name) {
          inherit (pcfg) name description avatar;
        }
      ) cfg.personas;
      default_persona = let first = lib.head (lib.attrValues (lib.mapAttrs' (n: _: lib.nameValuePair (personaId n) n) cfg.personas)); in first;
    };
  });

  ollamaSettingsMerge = if cfg.ollama.enable then ''
    OLLAMA_JSON="${pkgs.writeText "ollama-settings.json" ollamaSettingsJson}"
    if [ -f "''${SETTINGS}" ]; then
      ${pkgs.jq}/bin/jq -s '.[0] * .[1]' "''${SETTINGS}" "''${OLLAMA_JSON}" > "''${SETTINGS}.tmp" \
        && mv "''${SETTINGS}.tmp" "''${SETTINGS}"
      echo "sillytavern: merged Ollama connection profile(s) into settings.json"
    else
      cp "''${OLLAMA_JSON}" "''${SETTINGS}"
      echo "sillytavern: seeded settings.json with Ollama connection profile(s)"
    fi
  '' else "";

  ap = cfg.activePresets;

  activePresetsSettingsJson =
    let
      presetParts = builtins.filter (x: x != { }) [
        (if ap.context != null then { power_user = { context = { preset = ap.context; }; }; } else { })
        (if ap.theme != null then { power_user = { theme = ap.theme; }; } else { })
        (if ap.textgen != null then { preset_settings = ap.textgen; } else { })
        (if ap.openai != null then { oai_settings = { preset_settings_openai = ap.openai; }; } else { })
        (if ap.instruct != null then { power_user = { instruct = (cfg.presets.instruct.${ap.instruct} or {}) // { enabled = true; name = ap.instruct; }; }; } else { })
        (if ap.sysprompt != null then { power_user = { sysprompt = (cfg.presets.sysprompt.${ap.sysprompt} or {}) // { enabled = true; name = ap.sysprompt; }; }; } else { })
        (if ap.reasoning != null then { power_user = { reasoning = (cfg.presets.reasoning.${ap.reasoning} or {}) // { name = ap.reasoning; auto_parse = true; auto_expand = true; add_to_prompts = false; max_additions = 999; }; }; } else { })
      ];
    in
    builtins.toJSON (builtins.foldl' lib.recursiveUpdate { } presetParts);

  activePresetsMerge = if (ap.sysprompt != null || ap.context != null || ap.instruct != null || ap.reasoning != null || ap.textgen != null || ap.openai != null || ap.theme != null) then ''
    ACTIVE_JSON="${pkgs.writeText "active-presets.json" activePresetsSettingsJson}"
    if [ -f "''${SETTINGS}" ]; then
      ${pkgs.jq}/bin/jq -s '.[0] * .[1]' "''${SETTINGS}" "''${ACTIVE_JSON}" > "''${SETTINGS}.tmp" \
        && mv "''${SETTINGS}.tmp" "''${SETTINGS}"
      echo "sillytavern: merged active presets into settings.json"
    else
      cp "''${ACTIVE_JSON}" "''${SETTINGS}"
      echo "sillytavern: seeded settings.json with active presets"
    fi
  '' else "";

  vectfoxSettingsJson =
    if vfcfg.enable then builtins.toJSON {
      extension_settings = {
        vectfox = vfcfg // {
          enable = lib.mkDefault true;
        };
      };
    } else "null";

  vectfoxSettingsMerge = if vfcfg.enable then ''
    VF_JSON="${pkgs.writeText "vectfox-settings.json" vectfoxSettingsJson}"
    if [ -f "''${SETTINGS}" ]; then
      CURRENT=$(${pkgs.jq}/bin/jq -e '.extension_settings.vectfox // empty' "''${SETTINGS}" 2>/dev/null || echo "")
      if [ -z "$CURRENT" ]; then
        ${pkgs.jq}/bin/jq -s '.[0] * .[1]' "''${SETTINGS}" "''${VF_JSON}" > "''${SETTINGS}.tmp" \
          && mv "''${SETTINGS}.tmp" "''${SETTINGS}"
        echo "sillytavern: merged VectFox settings into settings.json"
      else
        echo "sillytavern: VectFox settings already present, skipping"
      fi
    else
      cp "''${VF_JSON}" "''${SETTINGS}"
      echo "sillytavern: seeded settings.json with VectFox settings"
    fi
  '' else "";

  extSettings = cfg.extensionSettings;

  extensionSettingsJson = if extSettings != { } then
    builtins.toJSON { extension_settings = extSettings; }
  else "null";

  extensionSettingsMerge = if extSettings != { } then ''
    EXT_JSON="${pkgs.writeText "extension-settings.json" extensionSettingsJson}"
    if [ -f "''${SETTINGS}" ]; then
      ${pkgs.jq}/bin/jq -s '.[0] * .[1]' "''${SETTINGS}" "''${EXT_JSON}" > "''${SETTINGS}.tmp" \
        && mv "''${SETTINGS}.tmp" "''${SETTINGS}"
      echo "sillytavern: merged extension settings into settings.json"
    else
      cp "''${EXT_JSON}" "''${SETTINGS}"
      echo "sillytavern: seeded settings.json with extension settings"
    fi
  '' else "";

  flattenEnv = attrs:
    let
      walk = parts: value:
        if builtins.isAttrs value && !builtins.isList value then
          lib.flip builtins.concatMap (builtins.attrNames value) (name:
            walk (parts ++ [ name ]) value.${name}
          )
        else
          let
            envKey = "SILLYTAVERN_" + lib.strings.toUpper (builtins.concatStringsSep "_" parts);
            envValue =
              if builtins.isBool value then lib.boolToString value
              else if builtins.isInt value then toString value
              else if builtins.isFloat value then toString value
              else if builtins.isString value then value
              else builtins.toJSON value;
          in
            [ { name = envKey; value = envValue; } ];
    in
    builtins.listToAttrs (walk [ ] attrs);

  seedScript = pkgs.writeShellScript "sillytavern-seed" ''
    set -euo pipefail
    mkdir -p "${stDataDir}"
    mkdir -p "${stUserDir}"

    ${cfg.presets.activationScript}

    ${if cfg.ollama.enable && cfg.ollama.models != { } then
      "echo \"sillytavern: pulling ollama models...\"\n${modelPullCmds}"
    else ""}

    SETTINGS="${stUserDir}/settings.json"
    ${ollamaSettingsMerge}
    ${if cfg.personas != { } then ''
      PERSONAS_JSON="${pkgs.writeText "personas-settings.json" personasSettingsJson}"
      if [ -f "''${SETTINGS}" ]; then
        ${pkgs.jq}/bin/jq -s '.[0] * .[1]' "''${SETTINGS}" "''${PERSONAS_JSON}" > "''${SETTINGS}.tmp" \
          && mv "''${SETTINGS}.tmp" "''${SETTINGS}"
        echo "sillytavern: merged personas into settings.json"
      else
        cp "''${PERSONAS_JSON}" "''${SETTINGS}"
        echo "sillytavern: seeded settings.json with personas"
      fi
    '' else ""}
    ${activePresetsMerge}
    ${vectfoxSettingsMerge}
    ${extensionSettingsMerge}

    chown -R ${cfg.user}:${cfg.group} "${homeDir}"
  '';
in
{
  config = lib.mkIf cfg.enable {
    systemd.services.sillytavern = {
      description = "SillyTavern LLM Frontend";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ] ++ lib.optionals cfg.ollama.enable [
        ollamaServiceName
      ] ++ lib.optionals (vfcfg.enable && vfcfg.backend == "qdrant") [
        "qdrant.service"
      ];
      wants = lib.optionals cfg.ollama.enable [
        ollamaServiceName
      ] ++ lib.optionals (vfcfg.enable && vfcfg.backend == "qdrant") [
        "qdrant.service"
      ];

      environment = flattenEnv cfg.settings // {
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
        TimeoutStartSec = "10min";
        WorkingDirectory = homeDir;
        StateDirectory = "sillytavern";
        StateDirectoryMode = "0750";
        ExecStartPre = "+${seedScript}";
        ExecStart = "${lib.getExe cfg.package}";
        ExecStartPost = "+${pkgs.writeShellScript "sillytavern-probe" ''
          echo "[sillytavern probe] waiting for API on port ${toString cfg.port}..."
          for i in $(${pkgs.coreutils}/bin/seq 1 30); do
            if ${pkgs.curl}/bin/curl -sf http://127.0.0.1:${toString cfg.port}/ > /dev/null 2>&1; then
              echo "[sillytavern probe] API reachable (attempt $i)"
              exit 0
            fi
            sleep 1
          done
          echo "[sillytavern probe] FAIL: API not reachable after 30s" >&2
          exit 1
        ''}";
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
