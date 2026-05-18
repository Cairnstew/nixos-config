{ config, lib, pkgs, ... }:

let
  inherit (lib) mkIf mkMerge;
  cfg = config.my.programs.opencode;

  # Count how many providers are active
  activeProviders = lib.filter (p: p != null) [
    (if cfg.openai.keyFile    != null then "openai"    else null)
    (if cfg.anthropic.keyFile != null then "anthropic" else null)
    (if cfg.google.keyFile    != null then "google"    else null)
    (if cfg.groq.keyFile      != null then "groq"      else null)
    (if cfg.mistral.keyFile   != null then "mistral"   else null)
    (if cfg.xai.keyFile       != null then "xai"       else null)
    (if cfg.together.keyFile  != null then "together"  else null)
    (if cfg.openrouter.keyFile != null then "openrouter" else null)
    (if cfg.fireworks.keyFile != null then "fireworks" else null)
    (if cfg.cerebras.keyFile  != null then "cerebras"  else null)
    (if cfg.deepinfra.keyFile != null then "deepinfra" else null)
    (if cfg.clarifai.patFile  != null then "clarifai"  else null)
    (if (cfg.azure.keyFile != null && cfg.azure.endpoint != null && cfg.azure.deployment != null) then "azure" else null)
    (if cfg.ollamaModels != {} then "ollama" else null)
  ];

  # Get the final opencode config that would be generated
  opencodeCfg = config.programs.opencode;

in {
  config = mkIf cfg.enable {
    # ── L0: Nix assertions ──────────────────────────────────────────────────
    assertions = [
      {
        assertion = cfg.model != null -> (lib.length activeProviders > 0);
        message = "my.programs.opencode: model is set but no providers are configured. "
                + "Enable at least one provider by setting its keyFile.";
      }
      {
        assertion = cfg.ollamaModels != {} -> cfg.ollamaBaseURL != "";
        message = "my.programs.opencode: ollamaModels is non-empty but ollamaBaseURL is empty.";
      }
      {
        assertion = cfg.azure.keyFile != null -> (cfg.azure.endpoint != null && cfg.azure.deployment != null);
        message = "my.programs.opencode: azure.keyFile is set but azure.endpoint and/or azure.deployment are missing.";
      }
      # Verify deepinfra provider is properly configured when keyFile is set
      {
        assertion = cfg.deepinfra.keyFile != null -> 
          (opencodeCfg.settings.provider.deepinfra.options.apiKey or "") == "{file:${cfg.deepinfra.keyFile}}";
        message = "my.programs.opencode: deepinfra provider not properly configured. Check that settings are being merged correctly.";
      }
      # Verify clarifai provider is properly configured when patFile is set
      {
        assertion = cfg.clarifai.patFile != null -> 
          (opencodeCfg.settings.provider.clarifai.options.apiKey or "") == "{file:${cfg.clarifai.patFile}}";
        message = "my.programs.opencode: clarifai provider not properly configured. Check that settings are being merged correctly.";
      }
      # Verify MCP integration is enabled if set
      {
        assertion = cfg.enableMcpIntegration -> opencodeCfg.enableMcpIntegration == true;
        message = "my.programs.opencode: MCP integration not properly enabled.";
      }
    ];

    # ── L1: Config validation ───────────────────────────────────────────────
    # Generate a test script that validates the opencode config
    home.file.".local/share/opencode/test-config.sh" = mkIf (cfg.deepinfra.keyFile != null || cfg.clarifai.patFile != null) {
      executable = true;
      text = ''
        #!/usr/bin/env bash
        set -euo pipefail
        
        CONFIG_FILE="$HOME/.config/opencode/config.json"
        
        if [ ! -f "$CONFIG_FILE" ]; then
          echo "ERROR: opencode config file not found at $CONFIG_FILE"
          exit 1
        fi
        
        echo "Checking opencode configuration..."
        
        # Check that the config is valid JSON
        if ! ${pkgs.jq}/bin/jq . "$CONFIG_FILE" > /dev/null 2>&1; then
          echo "ERROR: config.json is not valid JSON"
          exit 1
        fi
        
        ${lib.optionalString (cfg.deepinfra.keyFile != null) ''
          # Check deepinfra provider
          if ${pkgs.jq}/bin/jq -e '.provider.deepinfra' "$CONFIG_FILE" > /dev/null 2>&1; then
            echo "✓ deepinfra provider configured"
            API_KEY=$(${pkgs.jq}/bin/jq -r '.provider.deepinfra.options.apiKey // empty' "$CONFIG_FILE")
            if [ -n "$API_KEY" ]; then
              echo "✓ deepinfra apiKey is set"
            else
              echo "ERROR: deepinfra apiKey is empty or missing"
              exit 1
            fi
          else
            echo "ERROR: deepinfra provider not found in config"
            exit 1
          fi
        ''}
        
        ${lib.optionalString (cfg.clarifai.patFile != null) ''
          # Check clarifai provider
          if ${pkgs.jq}/bin/jq -e '.provider.clarifai' "$CONFIG_FILE" > /dev/null 2>&1; then
            echo "✓ clarifai provider configured"
            API_KEY=$(${pkgs.jq}/bin/jq -r '.provider.clarifai.options.apiKey // empty' "$CONFIG_FILE")
            if [ -n "$API_KEY" ]; then
              echo "✓ clarifai apiKey is set"
            else
              echo "ERROR: clarifai apiKey is empty or missing"
              exit 1
            fi
          else
            echo "ERROR: clarifai provider not found in config"
            exit 1
          fi
        ''}
        
        ${lib.optionalString cfg.enableMcpIntegration ''
          # Check MCP configuration
          if ${pkgs.jq}/bin/jq -e '.mcp' "$CONFIG_FILE" > /dev/null 2>&1; then
            echo "✓ MCP configuration present"
          else
            echo "WARNING: MCP configuration not found"
          fi
        ''}
        
        echo "All checks passed!"
      '';
    };
  };
}
