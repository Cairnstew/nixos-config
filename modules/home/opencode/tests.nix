{ config, lib, pkgs, ... }:

let
  inherit (lib) mkIf mkMerge;
  cfg = config.my.programs.opencode;

  # Count how many providers are active
  # Note: deepinfra is NOT included here because defining it in opencode.json breaks it
  activeProviders = lib.filter (p: p != null) [
    (if cfg.openai.keyFile != null then "openai" else null)
    (if cfg.anthropic.keyFile != null then "anthropic" else null)
    (if cfg.google.keyFile != null then "google" else null)
    (if cfg.groq.keyFile != null then "groq" else null)
    (if cfg.mistral.keyFile != null then "mistral" else null)
    (if cfg.xai.keyFile != null then "xai" else null)
    (if cfg.together.keyFile != null then "together" else null)
    (if cfg.openrouter.keyFile != null then "openrouter" else null)
    (if cfg.fireworks.keyFile != null then "fireworks" else null)
    (if cfg.cerebras.keyFile != null then "cerebras" else null)
    (if cfg.clarifai.patFile != null then "clarifai" else null)
    (if (cfg.azure.keyFile != null && cfg.azure.endpoint != null && cfg.azure.deployment != null) then "azure" else null)
    (if cfg.ollamaModels != { } then "ollama" else null)
  ];

  # Get the final opencode config that would be generated
  opencodeCfg = config.programs.opencode;

in
{
  config = mkIf cfg.enable {
    # ── L0: Nix assertions ──────────────────────────────────────────────────
    assertions = [
      {
        assertion = cfg.model != null -> (lib.length activeProviders > 0);
        message = "my.programs.opencode: model is set but no providers are configured. "
          + "Enable at least one provider by setting its keyFile.";
      }
      # ── modelFallback chain sanity ────────────────────────────────────────
      {
        assertion = lib.all (chain: chain != [ ])
          (lib.attrValues cfg.modelFallback.chains);
        message = "my.programs.opencode.modelFallback: every chain must be non-empty — "
          + "an empty chain would make the selector fail with no fallback at all.";
      }
      {
        assertion = lib.all
          (chain:
            let last = lib.last chain;
            in last.maxRollingPercent == null
              && last.maxWeeklyPercent == null
              && last.maxMonthlyPercent == null)
          (lib.attrValues cfg.modelFallback.chains);
        message = "my.programs.opencode.modelFallback: the LAST entry of every chain must be "
          + "cap-free (all max*Percent = null). It is the always-eligible safety net; a capped "
          + "last entry lets the whole chain exhaust under heavy usage.";
      }
      {
        # blockedTerminal entries (self-improve-limits Tier 1, D3): a chain
        # entry is either a model rung (model set, no marker) or the blocked
        # terminal marker — and the marker is only meaningful as the LAST
        # entry, where "no eligible model above it" must resolve to BLOCKED
        # (selector exit 5) instead of silently skipping past it.
        assertion = lib.all
          (entry:
            (entry.model != null) != entry.blockedTerminal)
          (lib.flatten (lib.attrValues cfg.modelFallback.chains));
        message = "my.programs.opencode.modelFallback: each chain entry must be exactly one of "
          + "a model rung (model set, blockedTerminal = false) or a blocked terminal "
          + "(blockedTerminal = true, model null).";
      }
      {
        assertion = lib.all
          (chain:
            lib.all (e: !e.blockedTerminal) (lib.init chain))
          (lib.attrValues cfg.modelFallback.chains);
        message = "my.programs.opencode.modelFallback: blockedTerminal is only valid as the "
          + "LAST entry of a chain — an earlier marker would short-circuit the chain.";
      }
      {
        assertion = !(cfg.modelFallback.syncEnsembleProjectFile && cfg.modelFallback.repoDir == "");
        message = "my.programs.opencode.modelFallback: syncEnsembleProjectFile is enabled but repoDir is empty.";
      }
      {
        # Pacing applies ONLY to weekly/monthly (rolling is a trailing 5h
        # sliding window with no fixed anchor — pacing tier0 findings §1).
        # Mirrors the eval-time throw in fallback.nix so this fails at the
        # assertions stage with a clearer location.
        assertion = lib.all
          (entry:
            !(entry.pacing.enable or false)
              || entry.maxWeeklyPercent != null
              || entry.maxMonthlyPercent != null)
          (lib.flatten (lib.attrValues cfg.modelFallback.chains));
        message = "my.programs.opencode.modelFallback: a chain entry sets pacing.enable "
          + "but constrains neither maxWeeklyPercent nor maxMonthlyPercent. The rolling "
          + "window cannot be paced (sliding, no anchor) — set a weekly/monthly cap or "
          + "drop pacing.enable.";
      }
      {
        assertion = cfg.ollamaModels != { } -> cfg.ollamaBaseURL != "";
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
      # learning-promoter-watcher requires opencode itself to be enabled
      {
        assertion = cfg.learningPromoterWatcher.enable -> cfg.enable;
        message = "my.programs.opencode: learningPromoterWatcher.enable requires my.programs.opencode.enable to be true.";
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
      # Verify plugins are passed through to settings correctly
      {
        assertion = cfg.plugins != [ ] -> builtins.length (builtins.filter (p: builtins.isString p) cfg.plugins) == builtins.length cfg.plugins;
        message = "my.programs.opencode.plugins: all entries must be strings (npm package names).";
      }
      # ── Ensemble fork invariant ──────────────────────────────────────────
      # opencode-ensemble is vendored as a local plugin fork (pluginFiles,
      # fork.nix + FORK.md) so the wake-path fix can be built in. An npm spec
      # for it would load a SECOND copy alongside the local fork (docs: npm +
      # local similar names both load) — double-loading tools and re-enabling
      # the unfixed upstream. Enforce the `plugins` array stays free of it.
      {
        assertion = !(builtins.elem "@hueyexe/opencode-ensemble" cfg.plugins);
        message = "my.programs.opencode.plugins: remove '@hueyexe/opencode-ensemble' from the npm plugins array — the ensemble is vendored as a local fork (pluginFiles.opencode-ensemble). A similar-named npm spec and local file BOTH load and would double-register tools. See FORK.md.";
      }
      # ── Decision 1 invariant (revised): promote-capable agents ─────────
      # build + learning-promoter may reach goals_learning_promote (no-human,
      # team-gated auto-improvement); every triage/reviewer role (scout,
      # reviewer, scout-skeptical, qa-verification, adversarial) must explicitly
      # deny it (defense-in-depth against mid-review capture). Enforce it so a
      # future edit can't silently make a triage role promote-capable or strip
      # the promoter's access, which would break the auto loop's trust model.
      {
        assertion =
          let
            promoteSetting = agent:
              (cfg.agents.${agent}.permission.tools.goals_learning_promote or "deny");
            denyOnlyAgents = lib.filter (n: n != "learning-promoter" && n != "build") (lib.attrNames cfg.agents);
          in
          cfg.agents ? "learning-promoter" && cfg.agents ? "build"
            && builtins.all (a: (promoteSetting a) != "allow") denyOnlyAgents;
        message = "my.programs.opencode: the 'learning-promoter' and 'build' agents must exist — they are the promote-capable agents (full-auto, team-gated promotion). All other agents (triage/reviewer roles) must deny goals_learning_promote.";
      }
      {
        assertion =
          let
            promoterSetting = cfg.agents."learning-promoter".permission.tools.goals_learning_promote or null;
          in
          cfg.agents ? "learning-promoter" -> promoterSetting == "allow";
        message = "my.programs.opencode: agent 'learning-promoter' must have goals_learning_promote = \"allow\" (it is the headless promoter).";
      }
    ] ++ (lib.concatLists (lib.mapAttrsToList
      (alias: ref: [
        {
          assertion = builtins.match "^[a-zA-Z0-9_-]+$" alias != null;
          message = "my.programs.opencode.references: '${alias}' contains invalid characters. "
            + "Aliases cannot contain /, whitespace, backticks, or commas.";
        }
        {
          assertion = ref.path != null || ref.repository != null;
          message = "my.programs.opencode.references: '${alias}' must set at least one of path or repository.";
        }
      ])
      cfg.references));

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
    home.file.".local/share/opencode/test-config.sh" = mkIf (cfg.clarifai.patFile != null || cfg.share != null || cfg.tui != { }) {
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
