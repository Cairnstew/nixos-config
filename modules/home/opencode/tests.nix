{ config, lib, pkgs, ... }:

let
  inherit (lib) mkIf mkMerge;
  cfg = config.my.programs.opencode;

  # Count how many providers are active
  # Note: deepinfra is NOT included here because defining it in opencode.json breaks it
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
      # Note: deepinfra is NOT verified here because defining it in opencode.json breaks it.
      # The API key is exported via shell init instead.
      # Verify clarifai provider is properly configured when patFile is set
      {
        assertion = cfg.clarifai.patFile != null ->
          (lib.hasPrefix "{file:" (opencodeCfg.settings.provider.clarifai.options.apiKey or ""));
        message = "my.programs.opencode: clarifai provider not properly configured. Check that settings are being merged correctly.";
      }
      # Verify MCP integration is enabled if set
      {
        assertion = cfg.enableMcpIntegration -> opencodeCfg.enableMcpIntegration == true;
        message = "my.programs.opencode: MCP integration not properly enabled.";
      }
      # Verify share value is valid
      {
        assertion = cfg.share != null -> (cfg.share == "manual" || cfg.share == "auto" || cfg.share == "disabled");
        message = "my.programs.opencode: share must be one of: manual, auto, or disabled.";
      }
      # Verify shorthand options are passed through correctly
      {
        assertion = cfg.smallModel != null -> opencodeCfg.settings.small_model == cfg.smallModel;
        message = "my.programs.opencode: smallModel shorthand not passed through correctly.";
      }
      {
        assertion = cfg.defaultAgent != null -> opencodeCfg.settings.default_agent == cfg.defaultAgent;
        message = "my.programs.opencode: defaultAgent shorthand not passed through correctly.";
      }
      {
        assertion = cfg.shell != null -> opencodeCfg.settings.shell == cfg.shell;
        message = "my.programs.opencode: shell shorthand not passed through correctly.";
      }
      {
        assertion = cfg.snapshot != null -> opencodeCfg.settings.snapshot == cfg.snapshot;
        message = "my.programs.opencode: snapshot shorthand not passed through correctly.";
      }
    ];

    # ── L1: Shell init — export secrets as env vars for SDK-based providers ─
    # OpenAI-compatible providers (Clarifai, etc.) use {file:...} syntax.
    # DeepInfra is handled here because defining it in opencode.json breaks it.
    programs.zsh.initContent = lib.optionalString cfg.enable ''
      ${lib.optionalString (cfg.groq.keyFile != null) ''
        export GROQ_API_KEY="$(cat ${cfg.groq.keyFile})"
      ''}
      ${lib.optionalString (cfg.openai.keyFile != null) ''
        export OPENAI_API_KEY="$(cat ${cfg.openai.keyFile})"
      ''}
      ${lib.optionalString (cfg.anthropic.keyFile != null) ''
        export ANTHROPIC_API_KEY="$(cat ${cfg.anthropic.keyFile})"
      ''}
      ${lib.optionalString (cfg.google.keyFile != null) ''
        export GOOGLE_GENERATIVE_AI_API_KEY="$(cat ${cfg.google.keyFile})"
      ''}
      ${lib.optionalString (cfg.mistral.keyFile != null) ''
        export MISTRAL_API_KEY="$(cat ${cfg.mistral.keyFile})"
      ''}
      ${lib.optionalString (cfg.xai.keyFile != null) ''
        export XAI_API_KEY="$(cat ${cfg.xai.keyFile})"
      ''}
      ${lib.optionalString (cfg.deepinfra.keyFile != null) ''
        export DEEPINFRA_API_KEY="$(cat ${cfg.deepinfra.keyFile})"
      ''}
    '';

    programs.bash.initExtra = lib.optionalString cfg.enable ''
      ${lib.optionalString (cfg.groq.keyFile != null) ''
        export GROQ_API_KEY="$(cat ${cfg.groq.keyFile})"
      ''}
      ${lib.optionalString (cfg.openai.keyFile != null) ''
        export OPENAI_API_KEY="$(cat ${cfg.openai.keyFile})"
      ''}
      ${lib.optionalString (cfg.anthropic.keyFile != null) ''
        export ANTHROPIC_API_KEY="$(cat ${cfg.anthropic.keyFile})"
      ''}
      ${lib.optionalString (cfg.google.keyFile != null) ''
        export GOOGLE_GENERATIVE_AI_API_KEY="$(cat ${cfg.google.keyFile})"
      ''}
      ${lib.optionalString (cfg.mistral.keyFile != null) ''
        export MISTRAL_API_KEY="$(cat ${cfg.mistral.keyFile})"
      ''}
      ${lib.optionalString (cfg.xai.keyFile != null) ''
        export XAI_API_KEY="$(cat ${cfg.xai.keyFile})"
      ''}
      ${lib.optionalString (cfg.deepinfra.keyFile != null) ''
        export DEEPINFRA_API_KEY="$(cat ${cfg.deepinfra.keyFile})"
      ''}
    '';

    # ── L2: Config validation script ────────────────────────────────────────
    home.file.".local/share/opencode/test-config.sh" = mkIf (cfg.clarifai.patFile != null || cfg.share != null || cfg.tui != {}) {
      executable = true;
      text = ''
        #!/usr/bin/env bash
        set -euo pipefail

        CONFIG_FILE="$HOME/.config/opencode/opencode.json"

        if [ ! -f "$CONFIG_FILE" ]; then
          echo "ERROR: opencode config file not found at $CONFIG_FILE"
          exit 1
        fi

        echo "Checking opencode configuration..."

        # Check that the config is valid JSON
        if ! ${pkgs.jq}/bin/jq . "$CONFIG_FILE" > /dev/null 2>&1; then
          echo "ERROR: opencode.json is not valid JSON"
          exit 1
        fi

        ${lib.optionalString (cfg.clarifai.patFile != null) ''
          # Check clarifai provider
          if ${pkgs.jq}/bin/jq -e '.provider.clarifai' "$CONFIG_FILE" > /dev/null 2>&1; then
            echo "✓ clarifai provider configured"
            API_KEY=$(${pkgs.jq}/bin/jq -r '.provider.clarifai.options.apiKey // empty' "$CONFIG_FILE")
            if [[ "$API_KEY" == {file:* ]]; then
              echo "✓ clarifai apiKey uses file substitution: $API_KEY"
            else
              echo "ERROR: clarifai apiKey should use {file:...} syntax (got: $API_KEY)"
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

        ${lib.optionalString (cfg.share != null) ''
          # Check share setting
          SHARE_VAL=$(${pkgs.jq}/bin/jq -r '.share // empty' "$CONFIG_FILE")
          if [ "$SHARE_VAL" = "${cfg.share}" ]; then
            echo "✓ share setting is correct: $SHARE_VAL"
          else
            echo "ERROR: share setting mismatch (expected: ${cfg.share}, got: $SHARE_VAL)"
            exit 1
          fi
        ''}

        ${lib.optionalString (cfg.smallModel != null) ''
          SMALL_MODEL=$(${pkgs.jq}/bin/jq -r '.small_model // empty' "$CONFIG_FILE")
          if [ "$SMALL_MODEL" = "${cfg.smallModel}" ]; then
            echo "✓ small_model setting is correct: $SMALL_MODEL"
          else
            echo "ERROR: small_model setting mismatch (expected: ${cfg.smallModel}, got: $SMALL_MODEL)"
            exit 1
          fi
        ''}

        ${lib.optionalString (cfg.defaultAgent != null) ''
          DEFAULT_AGENT=$(${pkgs.jq}/bin/jq -r '.default_agent // empty' "$CONFIG_FILE")
          if [ "$DEFAULT_AGENT" = "${cfg.defaultAgent}" ]; then
            echo "✓ default_agent setting is correct: $DEFAULT_AGENT"
          else
            echo "ERROR: default_agent setting mismatch (expected: ${cfg.defaultAgent}, got: $DEFAULT_AGENT)"
            exit 1
          fi
        ''}

        ${lib.optionalString (cfg.shell != null) ''
          SHELL_VAL=$(${pkgs.jq}/bin/jq -r '.shell // empty' "$CONFIG_FILE")
          if [ "$SHELL_VAL" = "${cfg.shell}" ]; then
            echo "✓ shell setting is correct: $SHELL_VAL"
          else
            echo "ERROR: shell setting mismatch (expected: ${cfg.shell}, got: $SHELL_VAL)"
            exit 1
          fi
        ''}

        ${lib.optionalString (cfg.snapshot != null) ''
          SNAPSHOT=$(${pkgs.jq}/bin/jq -r '.snapshot // empty' "$CONFIG_FILE")
          if [ "$SNAPSHOT" = "${lib.boolToString cfg.snapshot}" ]; then
            echo "✓ snapshot setting is correct: $SNAPSHOT"
          else
            echo "ERROR: snapshot setting mismatch (expected: ${lib.boolToString cfg.snapshot}, got: $SNAPSHOT)"
            exit 1
          fi
        ''}

        echo "All checks passed!"
      '';
    };
  };
}