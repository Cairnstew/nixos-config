{ config, lib, pkgs, ... }:

let
  inherit (lib)
    mkIf
    mkMerge
    recursiveUpdate
    filterAttrs
    mapAttrs
    optionalString
    ;

  cfg = config.my.programs.opencode;
  providers = import ./providers.nix { inherit lib cfg; };

  # Transform agent config to opencode.json format
  # Filter out null values for optional fields
  mkAgentConfig = agentCfg: {
    model = agentCfg.model;
    mode  = agentCfg.mode;
  }
  // (lib.optionalAttrs (agentCfg.temperature != null) { temperature = agentCfg.temperature; })
  // (lib.optionalAttrs (agentCfg.steps != null) { steps = agentCfg.steps; })
  // (lib.optionalAttrs (agentCfg.permission != null) {
    permission = filterAttrs (_: v: v != null) {
      edit = agentCfg.permission.edit;
      bash = agentCfg.permission.bash;
    };
  });

  agentSettings = lib.optionalAttrs (cfg.agents != {}) {
    agent = mapAttrs (_: mkAgentConfig) cfg.agents;
  };

  # Deep merge settings with provider settings, mcp settings, and agent settings
  # Use recursiveUpdate to merge nested attrsets properly
  settingsWithProviders = recursiveUpdate cfg.settings providers.allProviderSettings;
  settingsWithMcp = recursiveUpdate settingsWithProviders (
    lib.optionalAttrs (cfg.mcp != {}) { inherit (cfg) mcp; }
  );
  mergedSettings = recursiveUpdate settingsWithMcp agentSettings;

  # ── Auth.json entries for ALL providers ────────────────────────────────────
  # Format matches what `/connect` command writes:
  # { "provider-name": { "type": "api", "key": "actual-key" } }

  # Build list of all providers that need auth.json entries
  allAuthProviders = lib.filter (p: p.keyFile != null) [
    # First-class providers
    { name = "opencode-go";  keyFile = cfg.opencode-go.keyFile; }
    { name = "opencode-zen"; keyFile = cfg.opencode-zen.keyFile; }
    { name = "anthropic";    keyFile = cfg.anthropic.keyFile; }
    { name = "groq";         keyFile = cfg.groq.keyFile; }
    { name = "openai";       keyFile = cfg.openai.keyFile; }
    { name = "google";       keyFile = cfg.google.keyFile; }
    { name = "mistral";      keyFile = cfg.mistral.keyFile; }
    { name = "xai";          keyFile = cfg.xai.keyFile; }

    # OpenAI-compatible providers
    { name = "deepinfra";    keyFile = cfg.deepinfra.keyFile; }
    { name = "clarifai";     keyFile = cfg.clarifai.patFile; }
    { name = "together";     keyFile = cfg.together.keyFile; }
    { name = "fireworks";    keyFile = cfg.fireworks.keyFile; }
    { name = "cerebras";     keyFile = cfg.cerebras.keyFile; }
    { name = "openrouter";   keyFile = cfg.openrouter.keyFile; }

    # Azure
    { name = "azure";        keyFile = cfg.azure.keyFile; }
  ];

  hasAuthProviders = allAuthProviders != [];

  # Script to write auth.json, merging with existing entries
  # Uses jq to merge so existing providers (e.g., from /connect) are preserved
  writeAuthJsonScript = pkgs.writeShellScript "opencode-write-auth-json" ''
    set -euo pipefail

    AUTH_DIR="$HOME/.local/share/opencode"
    AUTH_FILE="$AUTH_DIR/auth.json"

    mkdir -p "$AUTH_DIR"

    # Initialize with empty object if file doesn't exist
    if [[ ! -f "$AUTH_FILE" ]]; then
      echo '{}' > "$AUTH_FILE"
    fi

    # Merge each provider entry into auth.json
    # Format: { "provider-name": { "type": "api", "key": "actual-key" } }
    ${lib.concatMapStringsSep "\n" (p: ''
      if [[ -r "${p.keyFile}" ]]; then
        key_value=$(cat "${p.keyFile}" | tr -d '\n')
        ${pkgs.jq}/bin/jq \
          --arg name "${p.name}" \
          --arg key "$key_value" \
          '. * {($name): { "type": "api", "key": $key }}' \
          "$AUTH_FILE" > "$AUTH_DIR/auth.json.tmp" && \
          mv "$AUTH_DIR/auth.json.tmp" "$AUTH_FILE"
      else
        echo "Warning: Cannot read ${p.name} key file: ${p.keyFile}" >&2
      fi
    '') allAuthProviders}

    # Ensure proper permissions
    chmod 600 "$AUTH_FILE" 2>/dev/null || true
  '';

in {
  config = mkIf cfg.enable (mkMerge [

    # Base opencode config
    {
      programs.opencode = {
        enable               = true;
        package              = cfg.package;
        enableMcpIntegration = cfg.enableMcpIntegration;
        context              = cfg.context;
        commands             = cfg.commands;
        themes               = cfg.themes;
        tui                  = cfg.tui;
        skills               = cfg.skills;
        tools                = cfg.tools;
        extraPackages        = cfg.extraPackages;
        settings             = mergedSettings;
      };
    }

    # ── Ollama: auto-select default model if one is tagged ──────────────────
    (mkIf (providers.defaultOllamaModel != null) {
      programs.opencode.settings.model = lib.mkDefault "ollama/${providers.defaultOllamaModel}";
    })

    # ── Shorthands (plain assignment = priority 100, overrides mkDefault) ───
    (mkIf (cfg.model        != null) { programs.opencode.settings.model        = cfg.model; })
    (mkIf (cfg.share        != null) { programs.opencode.settings.share        = cfg.share; })
    (mkIf (cfg.autoupdate   != null) { programs.opencode.settings.autoupdate   = cfg.autoupdate; })
    (mkIf (cfg.smallModel   != null) { programs.opencode.settings.small_model  = cfg.smallModel; })
    (mkIf (cfg.defaultAgent != null) { programs.opencode.settings.default_agent = cfg.defaultAgent; })
    (mkIf (cfg.shell        != null) { programs.opencode.settings.shell        = cfg.shell; })
    (mkIf (cfg.snapshot     != null) { programs.opencode.settings.snapshot     = cfg.snapshot; })

    # ── Write ALL provider credentials to auth.json ───────────────────────────
    (mkIf hasAuthProviders {
      home.activation.opencodeAuthJson = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        verboseEcho "Setting up OpenCode auth.json for providers..."
        ${writeAuthJsonScript}
      '';
    })

  ]);
}
