{ config, lib, pkgs, ... }:
let
  cfg = config.my.services.sillytavern;
  inherit (lib) mkIf;

  # Reuse the same deterministic ID generator from services.nix
  modelProfileId = tag:
    let h = builtins.hashString "sha256" "sillytavern-${tag}";
    in "${builtins.substring 0 8 h}-${builtins.substring 8 4 h}-${builtins.substring 12 4 h}-${builtins.substring 16 4 h}-${builtins.substring 20 12 h}";

  personaId = name:
    let h = builtins.hashString "sha256" "persona-${name}";
    in "${builtins.substring 0 8 h}-${builtins.substring 8 4 h}-${builtins.substring 12 4 h}-${builtins.substring 16 4 h}-${builtins.substring 20 12 h}";

  # Build jq queries for each active preset
  ap = cfg.activePresets;
  activePresetChecks = builtins.filter (x: x != "") [
    (if ap.sysprompt != null then ''
      echo "--- sysprompt: ${ap.sysprompt} ---"
      if ${pkgs.jq}/bin/jq -e '.power_user.sysprompt.name == "${ap.sysprompt}"' "$SETTINGS" > /dev/null 2>&1; then
        echo "PASS: sysprompt '${ap.sysprompt}' is active"
      else
        echo "FAIL: sysprompt '${ap.sysprompt}' not found in settings.json" >&2
        FAILED=$((FAILED + 1))
      fi
      if ${pkgs.jq}/bin/jq -e '.power_user.sysprompt.enabled == true' "$SETTINGS" > /dev/null 2>&1; then
        echo "PASS: sysprompt is enabled"
      else
        echo "FAIL: sysprompt not enabled" >&2
        FAILED=$((FAILED + 1))
      fi
    '' else "")
    (if ap.context != null then ''
      echo "--- context: ${ap.context} ---"
      if ${pkgs.jq}/bin/jq -e '.power_user.context.preset == "${ap.context}"' "$SETTINGS" > /dev/null 2>&1; then
        echo "PASS: context '${ap.context}' is active"
      else
        echo "FAIL: context '${ap.context}' not found in settings.json" >&2
        FAILED=$((FAILED + 1))
      fi
    '' else "")
    (if ap.instruct != null then ''
      echo "--- instruct: ${ap.instruct} ---"
      if ${pkgs.jq}/bin/jq -e '.power_user.instruct.name == "${ap.instruct}"' "$SETTINGS" > /dev/null 2>&1; then
        echo "PASS: instruct '${ap.instruct}' is active"
      else
        echo "FAIL: instruct '${ap.instruct}' not found in settings.json" >&2
        FAILED=$((FAILED + 1))
      fi
      if ${pkgs.jq}/bin/jq -e '.power_user.instruct.enabled == true' "$SETTINGS" > /dev/null 2>&1; then
        echo "PASS: instruct is enabled"
      else
        echo "FAIL: instruct not enabled" >&2
        FAILED=$((FAILED + 1))
      fi
    '' else "")
    (if ap.reasoning != null then ''
      echo "--- reasoning: ${ap.reasoning} ---"
      if ${pkgs.jq}/bin/jq -e '.power_user.reasoning.name == "${ap.reasoning}"' "$SETTINGS" > /dev/null 2>&1; then
        echo "PASS: reasoning '${ap.reasoning}' is active"
      else
        echo "FAIL: reasoning '${ap.reasoning}' not found in settings.json" >&2
        FAILED=$((FAILED + 1))
      fi
      if ${pkgs.jq}/bin/jq -e '.power_user.reasoning.auto_parse == true' "$SETTINGS" > /dev/null 2>&1; then
        echo "PASS: reasoning auto_parse is enabled"
      else
        echo "FAIL: reasoning auto_parse not enabled" >&2
        FAILED=$((FAILED + 1))
      fi
    '' else "")
    (if ap.textgen != null then ''
      echo "--- textgen: ${ap.textgen} ---"
      if ${pkgs.jq}/bin/jq -e '.preset_settings == "${ap.textgen}"' "$SETTINGS" > /dev/null 2>&1; then
        echo "PASS: textgen '${ap.textgen}' is active"
      else
        echo "FAIL: textgen '${ap.textgen}' not found in settings.json" >&2
        FAILED=$((FAILED + 1))
      fi
    '' else "")
    (if ap.openai != null then ''
      echo "--- openai: ${ap.openai} ---"
      if ${pkgs.jq}/bin/jq -e '.oai_settings.preset_settings_openai == "${ap.openai}"' "$SETTINGS" > /dev/null 2>&1; then
        echo "PASS: openai '${ap.openai}' is active"
      else
        echo "FAIL: openai '${ap.openai}' not found in settings.json" >&2
        FAILED=$((FAILED + 1))
      fi
    '' else "")
    (if ap.theme != null then ''
      echo "--- theme: ${ap.theme} ---"
      if ${pkgs.jq}/bin/jq -e '.power_user.theme == "${ap.theme}"' "$SETTINGS" > /dev/null 2>&1; then
        echo "PASS: theme '${ap.theme}' is active"
      else
        echo "FAIL: theme '${ap.theme}' not found in settings.json" >&2
        FAILED=$((FAILED + 1))
      fi
    '' else "")
  ];

  # Build persona check queries
  personaChecks = lib.concatStringsSep "\n" (lib.mapAttrsToList (name: pcfg: ''
    PID="${personaId name}"
    echo "--- persona '${pcfg.name}' (PID: $PID) ---"
    if ${pkgs.jq}/bin/jq -e '.power_user.personas."'"$PID"'"' "$SETTINGS" > /dev/null 2>&1; then
      echo "PASS: persona '${pcfg.name}' exists in settings.json"
    else
      echo "FAIL: persona '${pcfg.name}' not found" >&2
      FAILED=$((FAILED + 1))
    fi
    NAME=$(${pkgs.jq}/bin/jq -r '.power_user.personas."'"$PID"'".name' "$SETTINGS")
    if [ "$NAME" = "${pcfg.name}" ]; then
      echo "PASS: persona name matches"
    else
      echo "FAIL: persona name mismatch (expected '${pcfg.name}', got '$NAME')" >&2
      FAILED=$((FAILED + 1))
    fi
  '') cfg.personas);

  # Build ollama profile checks
  hasModels = cfg.ollama.enable && cfg.ollama.models != { };
  ollamaProfileChecks = if hasModels then
    lib.concatStringsSep "\n" (lib.mapAttrsToList (tag: mcfg:
      let pid = modelProfileId tag; in ''
        echo "--- ollama profile '${tag}' (${pid}) ---"
        if ${pkgs.jq}/bin/jq -e '.extension_settings.connectionManager.profiles[] | select(.id == "${pid}")' "$SETTINGS" > /dev/null 2>&1; then
          echo "PASS: profile '${tag}' exists in settings.json"
        else
          echo "FAIL: profile '${tag}' not found" >&2
          FAILED=$((FAILED + 1))
        fi
        PROFILE_API=$(${pkgs.jq}/bin/jq -r '.extension_settings.connectionManager.profiles[] | select(.id == "${pid}") | .api' "$SETTINGS")
        if [ "$PROFILE_API" = "ollama" ]; then
          echo "PASS: profile API is 'ollama'"
        else
          echo "FAIL: profile API is '$PROFILE_API' (expected 'ollama')" >&2
          FAILED=$((FAILED + 1))
        fi
        PROFILE_MODEL=$(${pkgs.jq}/bin/jq -r '.extension_settings.connectionManager.profiles[] | select(.id == "${pid}") | .model' "$SETTINGS")
        if [ "$PROFILE_MODEL" = "${tag}" ]; then
          echo "PASS: profile model tag matches"
        else
          echo "FAIL: profile model tag mismatch" >&2
          FAILED=$((FAILED + 1))
        fi
      '') cfg.ollama.models)
  else if cfg.ollama.enable then
    ''
      echo "--- default ollama profile ---"
      ${pkgs.jq}/bin/jq -e '.extension_settings.connectionManager.profiles[0].api == "ollama"' "$SETTINGS" > /dev/null 2>&1 && \
        echo "PASS: default ollama profile exists" || \
        { echo "FAIL: default ollama profile missing" >&2; FAILED=$((FAILED + 1)); }
    ''
  else "";

  # Build preset file checks for each category
  presetDirMap = {
    instruct = "instruct";
    context = "context";
    sysprompt = "sysprompt";
    textgen = "TextGen Settings";
    reasoning = "reasoning";
    kobold = "Kobold AI Settings";
    openai = "OpenAI Settings";
    themes = "themes";
    quickReplies = "quick-replies";
  };

  presetFileChecks = lib.concatStringsSep "\n" (lib.mapAttrsToList (optDir: fsDir:
    let entries = cfg.presets.${optDir} or { }; in
    if entries == { } then "" else
      lib.concatStringsSep "\n" (lib.mapAttrsToList (name: _: ''
        echo "--- ${fsDir}/${name}.json ---"
        if [ -f "${stUserDir}/${fsDir}/${name}.json" ]; then
          echo "PASS: preset file ${fsDir}/${name}.json exists"
          SIZE=$(stat -c%s "${stUserDir}/${fsDir}/${name}.json" 2>/dev/null || echo 0)
          if [ "$SIZE" -gt 5 ]; then
            echo "PASS: preset file size ($SIZE bytes) looks valid"
          else
            echo "WARN: preset file may be empty or too small ($SIZE bytes)"
          fi
          if ${pkgs.jq}/bin/jq -e '.' "${stUserDir}/${fsDir}/${name}.json" > /dev/null 2>&1; then
            echo "PASS: preset file is valid JSON"
          else
            echo "FAIL: preset file is not valid JSON" >&2
            FAILED=$((FAILED + 1))
          fi
          # Verify name field was injected
          NAME=$(${pkgs.jq}/bin/jq -r '.name // empty' "${stUserDir}/${fsDir}/${name}.json")
          if [ "$NAME" = "${name}" ]; then
            echo "PASS: preset has correct name field"
          else
            echo "FAIL: preset name field missing or incorrect (got '$NAME')" >&2
            FAILED=$((FAILED + 1))
          fi
        else
          echo "FAIL: preset file ${fsDir}/${name}.json does not exist" >&2
          FAILED=$((FAILED + 1))
        fi
      '') entries)
  ) presetDirMap);

  stateDir = "/var/lib/sillytavern";
  stDataDir = "${stateDir}/.local/share/SillyTavern";
  stUserDir = "${stDataDir}/data/default-user";

  hasAnyPersonas = cfg.personas != { };
  hasOllama = cfg.ollama.enable;
  hasVectfox = cfg.extensions.vectfox.enable;
  hasAnyActivePresets = ap.sysprompt != null || ap.context != null || ap.instruct != null || ap.reasoning != null || ap.textgen != null || ap.openai != null || ap.theme != null;

  # Third-party extension state
  tpexts = cfg.extensions.thirdParty;
  hasThirdParty = builtins.any (ecfg: ecfg.enable) (builtins.attrValues tpexts);
  enabledThirdParty = lib.filterAttrs (id: ecfg: ecfg.enable) tpexts;

  # Extension settings state
  extSettings = cfg.extensionSettings;
  hasExtensionSettings = extSettings != { };

  # Build third-party extension file checks
  thirdPartyFileChecks = if hasThirdParty then
    lib.concatStringsSep "\n" (lib.mapAttrsToList (id: ecfg: ''
      echo "--- third-party extension '${id}' ---"
      EXT_PATH="$ST_USER_DIR/extensions/${id}"
      if [ -d "$EXT_PATH" ]; then
        pass "Extension directory exists: ${id}"
      else
        fail "Extension directory missing: ${id}"
      fi
      if [ -f "$EXT_PATH/index.js" ]; then
        pass "Extension index.js exists: ${id}"
      else
        find "$EXT_PATH" -maxdepth 1 -name "*.js" 2>/dev/null | head -1 | read -r first_js
        if [ -f "$first_js" ] || [ -n "$first_js" ]; then
          pass "Extension has JS files: ${id}"
        else
          fail "Extension has no JS files: ${id}"
        fi
      fi
      if [ -f "$EXT_PATH/manifest.json" ]; then
        pass "Extension manifest.json exists: ${id}"
        if ${pkgs.jq}/bin/jq -e '.display_name' "$EXT_PATH/manifest.json" > /dev/null 2>&1; then
          NAME=$(${pkgs.jq}/bin/jq -r '.display_name' "$EXT_PATH/manifest.json")
          pass "Extension display name: $NAME"
        fi
      else
        info "No manifest.json for ${id} (optional for some extensions)"
      fi
    '') enabledThirdParty)
  else "";

  # Build extension settings checks
  extensionSettingsChecks = if hasExtensionSettings then
    lib.concatStringsSep "\n" (lib.mapAttrsToList (name: value: ''
      echo "--- extension setting '${name}' ---"
      if [ -f "$SETTINGS" ]; then
        if ${pkgs.jq}/bin/jq -e '.extension_settings."${name}"' "$SETTINGS" > /dev/null 2>&1; then
          pass "Extension setting '${name}' exists in settings.json"
        else
          fail "Extension setting '${name}' missing from settings.json"
        fi
      else
        fail "settings.json missing — cannot check extension settings"
      fi
    '') extSettings)
  else "";

  # Third-party extension validation
  thirdPartyErrors = lib.optional (hasThirdParty)
    (let
      msgs = lib.mapAttrsToList (id: ecfg:
        if ecfg.src == null && (ecfg.rev == null || ecfg.hash == null) then
          "my.services.sillytavern.extensions.thirdParty.${id} is enabled but missing rev+hash (and no src provided)"
        else ""
      ) enabledThirdParty;
      errors = builtins.filter (s: s != "") msgs;
    in errors);
  flatThirdPartyErrors = builtins.concatLists thirdPartyErrors;

  extensionSettingsErrors = lib.optional (hasExtensionSettings)
    (let
      msgs = lib.mapAttrsToList (name: value:
        if !builtins.isAttrs value then
          "my.services.sillytavern.extensionSettings.${name} must be an attrset"
        else ""
      ) extSettings;
      errors = builtins.filter (s: s != "") msgs;
    in errors);
  flatExtensionSettingsErrors = builtins.concatLists extensionSettingsErrors;

  # Check if any presets are configured
  hasAnyPresets =
    cfg.presets.instruct != { } ||
    cfg.presets.context != { } ||
    cfg.presets.sysprompt != { } ||
    cfg.presets.textgen != { } ||
    cfg.presets.reasoning != { } ||
    cfg.presets.kobold != { } ||
    cfg.presets.openai != { } ||
    cfg.presets.themes != { } ||
    cfg.presets.quickReplies != { };
in
{
  # ── L0: Nix Assertions ──────────────────────────────────────────────────────
  assertions = [
    # Core invariants
    {
      assertion = !cfg.enable || cfg.port > 0;
      message = "my.services.sillytavern.port must be a valid port number (> 0).";
    }
    {
      assertion = !cfg.enable || cfg.user != "";
      message = "my.services.sillytavern.user must not be empty.";
    }
    {
      assertion = !cfg.enable || cfg.group != "";
      message = "my.services.sillytavern.group must not be empty.";
    }

    # SSL configuration
    {
      assertion = !cfg.enable || !cfg.settings.ssl.enable || cfg.settings.ssl.certPath != "";
      message = "my.services.sillytavern.settings.ssl.certPath must not be empty when SSL is enabled.";
    }
    {
      assertion = !cfg.enable || !cfg.settings.ssl.enable || cfg.settings.ssl.keyPath != "";
      message = "my.services.sillytavern.settings.ssl.keyPath must not be empty when SSL is enabled.";
    }

    # Whistlist mode
    {
      assertion = !cfg.enable || !cfg.whitelistMode || cfg.whitelistAddresses != [];
      message = "my.services.sillytavern.whitelistAddresses must not be empty when whitelistMode is enabled.";
    }

    # Basic auth
    {
      assertion = !cfg.enable || !cfg.basicAuthMode || cfg.basicAuthUser != "";
      message = "my.services.sillytavern.basicAuthUser must not be empty when basicAuthMode is enabled.";
    }
    {
      assertion = !cfg.enable || !cfg.basicAuthMode || cfg.basicAuthPassword != "";
      message = "my.services.sillytavern.basicAuthPassword must not be empty when basicAuthMode is enabled.";
    }

    # Ollama integration
    {
      assertion = !cfg.enable || !cfg.ollama.enable || cfg.ollama.host != "";
      message = "my.services.sillytavern.ollama.host must not be empty when ollama integration is enabled.";
    }
    {
      assertion = !cfg.enable || !cfg.ollama.enable || cfg.ollama.port > 0;
      message = "my.services.sillytavern.ollama.port must be a valid port number.";
    }

    # Active preset validation — each named preset must exist in its corresponding category
    {
      assertion = !cfg.enable || ap.sysprompt == null || builtins.hasAttr ap.sysprompt cfg.presets.sysprompt;
      message = "my.services.sillytavern.activePresets.sysprompt = \"${toString ap.sysprompt}\" but no such preset exists in presets.sysprompt.";
    }
    {
      assertion = !cfg.enable || ap.context == null || builtins.hasAttr ap.context cfg.presets.context;
      message = "my.services.sillytavern.activePresets.context = \"${toString ap.context}\" but no such preset exists in presets.context.";
    }
    {
      assertion = !cfg.enable || ap.instruct == null || builtins.hasAttr ap.instruct cfg.presets.instruct;
      message = "my.services.sillytavern.activePresets.instruct = \"${toString ap.instruct}\" but no such preset exists in presets.instruct.";
    }
    {
      assertion = !cfg.enable || ap.reasoning == null || builtins.hasAttr ap.reasoning cfg.presets.reasoning;
      message = "my.services.sillytavern.activePresets.reasoning = \"${toString ap.reasoning}\" but no such preset exists in presets.reasoning.";
    }
    {
      assertion = !cfg.enable || ap.textgen == null || builtins.hasAttr ap.textgen cfg.presets.textgen;
      message = "my.services.sillytavern.activePresets.textgen = \"${toString ap.textgen}\" but no such preset exists in presets.textgen.";
    }
    {
      assertion = !cfg.enable || ap.openai == null || builtins.hasAttr ap.openai cfg.presets.openai;
      message = "my.services.sillytavern.activePresets.openai = \"${toString ap.openai}\" but no such preset exists in presets.openai.";
    }
    {
      assertion = !cfg.enable || ap.theme == null || builtins.hasAttr ap.theme cfg.presets.themes;
      message = "my.services.sillytavern.activePresets.theme = \"${toString ap.theme}\" but no such preset exists in presets.themes.";
    }

    # VectFox
    {
      assertion = !cfg.enable || !hasVectfox || cfg.extensions.vectfox.backend == "standard" || cfg.extensions.vectfox.backend == "qdrant";
      message = "my.services.sillytavern.extensions.vectfox.backend must be 'standard' or 'qdrant'.";
    }

    # Third-party extensions — require rev+hash or src when enabled
    {
      assertion = !hasThirdParty || flatThirdPartyErrors == [ ];
      message = lib.concatStringsSep "\n" flatThirdPartyErrors;
    }

    # Extension settings — must be attrs
    {
      assertion = !hasExtensionSettings || flatExtensionSettingsErrors == [ ];
      message = lib.concatStringsSep "\n" flatExtensionSettingsErrors;
    }
  ];

  # ── L2: Smoke Test Service ──────────────────────────────────────────────
  systemd.services.sillytavern-smoke-test = mkIf cfg.enable {
    description = "Comprehensive smoke test for SillyTavern";
    after = [ "sillytavern.service" ];
    requires = [ "sillytavern.service" ];

    serviceConfig.Type = "oneshot";

    script = ''
      set -euo pipefail
      FAILED=0
      TOTAL=0
      PASSED=0
      HOME_DIR="${stateDir}"
      ST_DIR="${stDataDir}"
      ST_USER_DIR="${stUserDir}"
      SETTINGS="${stUserDir}/settings.json"

      section() {
        TOTAL=$((TOTAL + 1))
        echo ""
        echo "═══ [$TOTAL] $1 ═══"
      }

      pass() {
        echo "  PASS: $1"
        PASSED=$((PASSED + 1))
      }

      fail() {
        echo "  FAIL: $1" >&2
        FAILED=$((FAILED + 1))
      }

      info() {
        echo "  INFO: $1"
      }

      # ── [1] Binary & Service ──────────────────────────────────────────────
      section "Binary & Service"

      if [ -x "${lib.getExe cfg.package}" ]; then
        pass "SillyTavern binary is executable"
      else
        fail "SillyTavern binary not found or not executable"
      fi

      if systemctl list-unit-files sillytavern.service > /dev/null 2>&1; then
        pass "sillytavern.service unit exists"
      else
        fail "sillytavern.service unit not found"
      fi

      if systemctl is-enabled sillytavern.service > /dev/null 2>&1; then
        pass "sillytavern.service is enabled"
      else
        fail "sillytavern.service is not enabled"
      fi

      if systemctl is-active sillytavern.service > /dev/null 2>&1; then
        pass "sillytavern.service is active"
      else
        info "sillytavern.service is not active (may need start)"
      fi

      # ── [2] State Directory Structure ──────────────────────────────────────
      section "State Directory Structure"

      DIRS=(
        "$HOME_DIR"
        "$ST_DIR"
        "$ST_USER_DIR"
      )
      for d in "''${DIRS[@]}"; do
        if [ -d "$d" ]; then
          pass "Directory exists: $d"
          PERMS=$(stat -c '%a' "$d")
          info "  Permissions: $PERMS"
          OWNER=$(stat -c '%U:%G' "$d")
          info "  Owner: $OWNER"
        else
          fail "Directory missing: $d"
        fi
      done

      # ── [3] Preset Directories ─────────────────────────────────────────────
      section "Preset Directories (all 9 categories)"

      PRESET_DIRS=(
        "instruct"
        "context"
        "sysprompt"
        "TextGen Settings"
        "reasoning"
        "Kobold AI Settings"
        "OpenAI Settings"
        "themes"
        "quick-replies"
      )
      for d in "''${PRESET_DIRS[@]}"; do
        if [ -d "$ST_USER_DIR/$d" ]; then
          pass "Preset directory exists: $d"
        else
          fail "Preset directory missing: $d"
        fi
      done

      # ── [4] Preset Files ───────────────────────────────────────────────────
      section "Preset Files"
      ${if hasAnyPresets then presetFileChecks else ''
        info "No presets configured (skipping file checks)"
      ''}

      # ── [5] settings.json ──────────────────────────────────────────────────
      section "settings.json"

      if [ -f "$SETTINGS" ]; then
        pass "settings.json exists"
        SIZE=$(stat -c%s "$SETTINGS")
        info "  File size: $SIZE bytes"
        if [ "$SIZE" -gt 10 ]; then
          pass "settings.json size looks valid"
        else
          fail "settings.json too small ($SIZE bytes)"
        fi
        if ${pkgs.jq}/bin/jq -e '.' "$SETTINGS" > /dev/null 2>&1; then
          pass "settings.json is valid JSON"
        else
          fail "settings.json is not valid JSON"
        fi

        # Check settings.json has expected top-level structure
        TOP_KEYS=$(${pkgs.jq}/bin/jq -r 'keys | join(",")' "$SETTINGS")
        info "  Top-level keys: $TOP_KEYS"
      else
        fail "settings.json does not exist"
      fi

      # ── [6] Ollama Integration ─────────────────────────────────────────────
      section "Ollama Integration"
      if [ "${lib.boolToString hasOllama}" = "true" ]; then
        if [ -f "$SETTINGS" ]; then
          # Check ollama server entry
          if ${pkgs.jq}/bin/jq -e '.power_user.servers[] | select(.label == "ollama")' "$SETTINGS" > /dev/null 2>&1; then
            pass "Ollama server entry exists in settings.json"
          else
            fail "Ollama server entry not found in settings.json"
          fi

          # Check connection manager profiles exist
          if ${pkgs.jq}/bin/jq -e '.extension_settings.connectionManager.profiles | length > 0' "$SETTINGS" > /dev/null 2>&1; then
            pass "Connection manager has profiles"
            PROFILE_COUNT=$(${pkgs.jq}/bin/jq -r '.extension_settings.connectionManager.profiles | length' "$SETTINGS")
            info "  Profile count: $PROFILE_COUNT"
          else
            fail "Connection manager has no profiles"
          fi

          # Check selected profile is set
          SELECTED=$(${pkgs.jq}/bin/jq -r '.extension_settings.connectionManager.selectedProfile // ""' "$SETTINGS")
          if [ -n "$SELECTED" ]; then
            pass "Selected profile ID is non-empty: $SELECTED"
          else
            info "No profile selected (may need first manual selection)"
          fi

          ${ollamaProfileChecks}
        else
          fail "settings.json missing — cannot check ollama integration"
        fi
      else
        info "Ollama integration not enabled (skipping)"
      fi

      # ── [7] VectFox ────────────────────────────────────────────────────────
      section "VectFox"
      if [ "${lib.boolToString hasVectfox}" = "true" ]; then
        STORE="${lib.getExe cfg.package}"
        EXT_DIR="$STORE/lib/node_modules/sillytavern/public/scripts/extensions/third-party/VectFox"
        PLUGIN_DIR="$STORE/lib/node_modules/sillytavern/plugins/similharity"

        if [ -f "$EXT_DIR/manifest.json" ]; then
          pass "VectFox extension manifest.json exists"
        else
          fail "VectFox extension manifest.json missing"
        fi
        if [ -f "$EXT_DIR/index.js" ]; then
          pass "VectFox extension index.js exists"
        else
          fail "VectFox extension index.js missing"
        fi
        if [ -d "$EXT_DIR/core" ]; then
          pass "VectFox extension core/ directory exists"
        else
          fail "VectFox extension core/ directory missing"
        fi
        if [ -d "$EXT_DIR/ui" ]; then
          pass "VectFox extension ui/ directory exists"
        else
          fail "VectFox extension ui/ directory missing"
        fi
        if [ -d "$EXT_DIR/backends" ]; then
          pass "VectFox extension backends/ directory exists"
        else
          fail "VectFox extension backends/ directory missing"
        fi

        if [ -f "$PLUGIN_DIR/index.js" ]; then
          pass "Similharity plugin index.js exists"
        else
          fail "Similharity plugin index.js missing"
        fi
        if [ -d "$PLUGIN_DIR/node_modules" ]; then
          pass "Similharity plugin node_modules/ exists"
        else
          fail "Similharity plugin node_modules/ missing"
        fi

        # Check VectFox backend in settings.json
        if [ -f "$SETTINGS" ]; then
          VF_BACKEND=$(${pkgs.jq}/bin/jq -r '.extension_settings.vectfox.backend // ""' "$SETTINGS")
          if [ -n "$VF_BACKEND" ]; then
            pass "VectFox backend set to '$VF_BACKEND' in settings.json"
          else
            info "VectFox backend not yet set in settings.json (will be set on first seed)"
          fi
        fi
      else
        info "VectFox not enabled (skipping)"
      fi

      # ── [8] Third-Party Extensions ───────────────────────────────────────────
      section "Third-Party Extensions"
      if [ "${lib.boolToString hasThirdParty}" = "true" ]; then
        ${thirdPartyFileChecks}
        NUM_EXTENSIONS=$(${pkgs.findutils}/bin/find "$ST_USER_DIR/extensions" -maxdepth 1 -type d 2>/dev/null | wc -l)
        info "Total extension directories: $NUM_EXTENSIONS"
      else
        info "No third-party extensions configured (skipping)"
      fi

      # ── [9] Personas ───────────────────────────────────────────────────────
      section "Personas"
      if [ "${lib.boolToString hasAnyPersonas}" = "true" ]; then
        if [ -f "$SETTINGS" ]; then
          if ${pkgs.jq}/bin/jq -e '.power_user.personas | length > 0' "$SETTINGS" > /dev/null 2>&1; then
            pass "Personas section exists in settings.json with entries"
          else
            fail "Personas section missing or empty in settings.json"
          fi

          # Check default_persona is set
          if ${pkgs.jq}/bin/jq -e '.power_user.default_persona | length > 0' "$SETTINGS" > /dev/null 2>&1; then
            pass "Default persona is set"
            DEF_ID=$(${pkgs.jq}/bin/jq -r '.power_user.default_persona' "$SETTINGS")
            info "  Default persona ID: $DEF_ID"
          else
            info "No default persona set"
          fi

          ${personaChecks}
        else
          fail "settings.json missing — cannot check personas"
        fi
      else
        info "No personas configured (skipping)"
      fi

      # ── [8] Active Presets ─────────────────────────────────────────────────
      section "Active Presets"
      if [ "${lib.boolToString hasAnyActivePresets}" = "true" ]; then
        if [ -f "$SETTINGS" ]; then
          ${builtins.concatStringsSep "\n" activePresetChecks}
        else
          fail "settings.json missing — cannot check active presets"
        fi
      else
        info "No active presets configured (skipping)"
      fi

      # ── [10] Extension Settings ────────────────────────────────────────────
      section "Extension Settings"
      if [ "${lib.boolToString hasExtensionSettings}" = "true" ]; then
        ${extensionSettingsChecks}
      else
        info "No extension settings configured (skipping)"
      fi

      # ── [11] Environment Variables ─────────────────────────────────────────
      section "Environment Variables"

      if systemctl show sillytavern.service -p Environment > /dev/null 2>&1; then
        ENV_OUTPUT=$(systemctl show sillytavern.service -p Environment 2>/dev/null || true)
        if echo "$ENV_OUTPUT" | grep -q "SILLYTAVERN_PORT=${toString cfg.port}"; then
          pass "SILLYTAVERN_PORT=${toString cfg.port} is set in service environment"
        else
          info "SILLYTAVERN_PORT env check inconclusive (may use config.yaml instead)"
        fi

        if echo "$ENV_OUTPUT" | grep -q "SILLYTAVERN_LISTEN"; then
          pass "SILLYTAVERN_LISTEN is set in service environment"
        else
          info "SILLYTAVERN_LISTEN env check"
        fi

        if [ "${lib.boolToString cfg.basicAuthMode}" = "true" ]; then
          if echo "$ENV_OUTPUT" | grep -q "SILLYTAVERN_BASICAUTHMODE=true"; then
            pass "SILLYTAVERN_BASICAUTHMODE=true is set"
          else
            info "SILLYTAVERN_BASICAUTHMODE not found in environment"
          fi
        fi
      else
        info "Cannot inspect sillytavern.service environment"
      fi

      # ── [12] API Reachability ──────────────────────────────────────────────
      section "API Reachability"
      if systemctl is-active sillytavern.service > /dev/null 2>&1; then
        echo "Checking API on http://127.0.0.1:${toString cfg.port}/ ..."
        if ${pkgs.curl}/bin/curl -sf http://127.0.0.1:${toString cfg.port}/ > /dev/null 2>&1; then
          pass "SillyTavern API reachable on port ${toString cfg.port}"
        else
          fail "SillyTavern API unreachable on port ${toString cfg.port}"
        fi
      else
        info "SillyTavern service not active — skipping API reachability check"
      fi

      # ── Summary ────────────────────────────────────────────────────────────
      echo ""
      echo "═══ SillyTavern Smoke Test Complete: $TOTAL sections, $PASSED passed, $FAILED failed ═══"
      if [ "$FAILED" -gt 0 ]; then
        exit 1
      fi
    '';
  };
}
