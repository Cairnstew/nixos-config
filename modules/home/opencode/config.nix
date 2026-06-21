{ config, lib, pkgs, ... }:

let
  inherit (lib)
    mkIf
    mkMerge
    recursiveUpdate
    filterAttrs
    mapAttrs
    mapAttrsToList
    optionalString
    ;

  cfg = config.my.programs.opencode;

  # Wrap opencode so libstdc++.so.6 is available for the native file watcher
  # binding (e.g. chokidar / fsevents). On NixOS this is not in the default
  # library path.
  opencodeWrapped = pkgs.symlinkJoin {
    name = "opencode-wrapped";
    paths = [ cfg.package ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram "$out/bin/opencode" \
        --prefix LD_LIBRARY_PATH : "${pkgs.lib.makeLibraryPath [ pkgs.stdenv.cc.cc.lib ]}"
    '';
  };
  providers = import ./providers.nix { inherit lib cfg; };

  # Transform agent config to opencode.json format
  # Omit null/false values so only relevant fields appear in the JSON
  mkAgentConfig = agentCfg:
    (lib.optionalAttrs (agentCfg.model != null) { model = agentCfg.model; })
    // (lib.optionalAttrs (agentCfg.mode != null) { mode = agentCfg.mode; })
    // (lib.optionalAttrs (agentCfg.description != null) { description = agentCfg.description; })
    // (lib.optionalAttrs (agentCfg.prompt != null) { prompt = agentCfg.prompt; })
    // (lib.optionalAttrs (agentCfg.temperature != null) { temperature = agentCfg.temperature; })
    // (lib.optionalAttrs (agentCfg.top_p != null) { top_p = agentCfg.top_p; })
    // (lib.optionalAttrs (agentCfg.steps != null) { steps = agentCfg.steps; })
    // (lib.optionalAttrs agentCfg.disable { disable = true; })
    // (lib.optionalAttrs agentCfg.hidden { hidden = true; })
    // (lib.optionalAttrs (agentCfg.color != null) { color = agentCfg.color; })
    // (lib.optionalAttrs (agentCfg.permission != null) {
      permission = filterAttrs (_: v: v != null) {
        inherit (agentCfg.permission)
          read edit glob grep list bash task external_directory
          lsp skill todowrite webfetch websearch question doom_loop;
      };
    })
    // agentCfg.extraOptions;

  agentSettings = lib.optionalAttrs (cfg.agents != { }) {
    agent = mapAttrs (_: mkAgentConfig) cfg.agents;
  };

  # Transform references to opencode JSON format
  # Omit null/empty fields so only the relevant ones appear in the JSON
  mkReference = ref:
    { path = ref.path; }
    // (lib.optionalAttrs (ref.repository != null) { repository = ref.repository; })
    // (lib.optionalAttrs (ref.branch != null) { branch = ref.branch; })
    // (lib.optionalAttrs (ref.description != null) { description = ref.description; })
    // (lib.optionalAttrs ref.hidden { hidden = true; });

  referencesSettings = lib.optionalAttrs (cfg.references != { }) {
    references = mapAttrs (_: mkReference) cfg.references;
  };

  # Deep merge settings with provider, mcp, references, plugins, and agent settings
  # Use recursiveUpdate to merge nested attrsets properly
  settingsWithProviders = recursiveUpdate cfg.settings providers.allProviderSettings;
  settingsWithMcp = recursiveUpdate settingsWithProviders (
    lib.optionalAttrs (cfg.mcp != { }) { inherit (cfg) mcp; }
  );
  settingsWithReferences = recursiveUpdate settingsWithMcp referencesSettings;
  settingsWithPlugins = recursiveUpdate settingsWithReferences (
    lib.optionalAttrs (cfg.plugins != [ ]) { plugin = cfg.plugins; }
  );
  mergedSettings = recursiveUpdate (recursiveUpdate settingsWithPlugins agentSettings) policySettings;

  # ── Provider access policies ────────────────────────────────────────────────
  # Generate deny-all-then-allow-listed policy rules from cfg.policies
  policyRules = builtins.concatLists [
    # When policies are enabled, deny all providers first, then allow listed ones
    (lib.optional cfg.policies.enable {
      effect = "deny";
      action = "provider.use";
      resource = "*";
    })
    (builtins.map (provider: {
      effect = "allow";
      action = "provider.use";
      resource = provider;
    }) cfg.policies.allowedProviders)
    # Append any extra user-defined policies
    cfg.policies.extraPolicies
  ];

  policySettings = lib.optionalAttrs (policyRules != [ ]) {
    experimental.policies = policyRules;
  };

  # ── Auth.json entries for ALL providers ────────────────────────────────────
  # Format matches what `/connect` command writes:
  # { "provider-name": { "type": "api", "key": "actual-key" } }

  # Build list of all providers that need auth.json entries
  allAuthProviders = lib.filter (p: p.keyFile != null) [
    # First-class providers
    { name = "opencode-go"; keyFile = cfg.opencode-go.keyFile; }
    { name = "opencode-zen"; keyFile = cfg.opencode-zen.keyFile; }
    { name = "anthropic"; keyFile = cfg.anthropic.keyFile; }
    { name = "groq"; keyFile = cfg.groq.keyFile; }
    { name = "openai"; keyFile = cfg.openai.keyFile; }
    { name = "google"; keyFile = cfg.google.keyFile; }
    { name = "mistral"; keyFile = cfg.mistral.keyFile; }
    { name = "xai"; keyFile = cfg.xai.keyFile; }

    # OpenAI-compatible providers
    { name = "deepinfra"; keyFile = cfg.deepinfra.keyFile; }
    { name = "clarifai"; keyFile = cfg.clarifai.patFile; }
    { name = "together"; keyFile = cfg.together.keyFile; }
    { name = "fireworks"; keyFile = cfg.fireworks.keyFile; }
    { name = "cerebras"; keyFile = cfg.cerebras.keyFile; }
    { name = "openrouter"; keyFile = cfg.openrouter.keyFile; }

    # Azure
    { name = "azure"; keyFile = cfg.azure.keyFile; }
  ];

  hasAuthProviders = allAuthProviders != [ ];

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

in
{
  config = mkIf cfg.enable (mkMerge [

    # ── Default agents, tools, skills (mkDefault = overridable by host configs) ─
    # Tools use path references to .ts files in ./tools/ — these resolve relative to
    # this file at parse time.  Host configs can override individual entries or replace
    # the entire attrset (plain assignment beats mkDefault).
    {
      my.programs.opencode = {
        agents = lib.mkDefault {
          plan = {
            description = "Analyze code and review suggestions without making changes";
            model = "opencode-go/deepseek-v4-flash";
            mode = "primary";
            temperature = 0.1;
            steps = 10;
            permission = { edit = "deny"; bash = "deny"; };
          };
          explore = {
            description = "Quickly explore the codebase by searching files, patterns, and keywords (read-only)";
            model = "opencode-go/deepseek-v4-flash";
            mode = "subagent";
            temperature = 0.1;
            permission = { edit = "deny"; bash = "deny"; };
          };
          build = {
            description = "Standard development agent with full tool access";
            model = "opencode-go/deepseek-v4-flash";
            mode = "primary";
            permission = { edit = "allow"; bash = "allow"; };
          };
        };
        tools = lib.mkDefault {
          tailscale-manager = ./tools/tailscale-manager.ts;
          agenix-manager = ./tools/agenix-manager.ts;
          nix-hosts = ./tools/nix-hosts.ts;
          nix-eval = ./tools/nix-eval.ts;
          nix-flake-check = ./tools/nix-flake-check.ts;
          just = ./tools/just.ts;
        };
        skills = lib.mkDefault {
          git-repo-management = builtins.readFile ./skills/git-repo-management.md;
          nixos-configuration = builtins.readFile ./skills/nixos-configuration.md;
          module-development = builtins.readFile ./skills/module-development.md;
          deploy-workflow = builtins.readFile ./skills/deploy-workflow.md;
          secrets-management = builtins.readFile ./skills/secrets-management.md;
          testing-patterns = builtins.readFile ./skills/testing-patterns.md;
          windows-integration = builtins.readFile ./skills/windows-integration.md;
          docker-management = builtins.readFile ./skills/docker-management.md;
        };
        commands = lib.mkDefault {
          copy-last = ./commands/copylast.md;
          refactor-python = ./commands/refactor-python.md;
        };
      };
    }

    # Base opencode config
    {
      programs.opencode = {
        enable = true;
        package = opencodeWrapped;
        enableMcpIntegration = cfg.enableMcpIntegration;
        context = cfg.context;
        commands = cfg.commands;
        themes = cfg.themes;
        tui = lib.mkDefault cfg.tui;
        skills = cfg.skills;
        tools = cfg.tools;
        extraPackages = cfg.extraPackages ++ lib.optionals cfg.enableLsp [ pkgs.nixd ];
        settings = mergedSettings // lib.optionalAttrs cfg.enableLsp { lsp = true; };
      };
    }

    # ── Local plugin files ──────────────────────────────────────────────────
    (mkIf (cfg.pluginFiles != { }) {
      home.file = builtins.listToAttrs (mapAttrsToList (name: src: {
        name = ".config/opencode/plugins/${name}.js";
        value = if builtins.isPath src
          then { source = src; }
          else { text = src; };
      }) cfg.pluginFiles);
    })

    # Default permissions for NixOS paths & Ensemble worktrees
    {
      programs.opencode.settings.permission = lib.mkDefault {
        external_directory = {
          "/nix/*" = "allow";
          "/nix/store/**" = "allow";
          "/nix/var/nix/**" = "allow";
          "/run/current-system/**" = "allow";
          "/run/agenix/**" = "allow";
          "/etc/nixos/**" = "allow";
          "/tmp/*" = "allow";
          "~/.local/share/opencode/worktree/**" = "allow";
        };
      };
    }

    # ── Ollama: auto-select default model if one is tagged ──────────────────
    (mkIf (providers.defaultOllamaModel != null) {
      programs.opencode.settings.model = lib.mkDefault "ollama/${providers.defaultOllamaModel}";
    })

    # ── Shorthands (plain assignment = priority 100, overrides mkDefault) ───
    (mkIf (cfg.model != null) { programs.opencode.settings.model = cfg.model; })
    (mkIf (cfg.share != null) { programs.opencode.settings.share = cfg.share; })
    (mkIf (cfg.autoupdate != null) { programs.opencode.settings.autoupdate = cfg.autoupdate; })
    (mkIf (cfg.smallModel != null) { programs.opencode.settings.small_model = cfg.smallModel; })
    (mkIf (cfg.defaultAgent != null) { programs.opencode.settings.default_agent = cfg.defaultAgent; })
    (mkIf (cfg.shell != null) { programs.opencode.settings.shell = cfg.shell; })
    (mkIf (cfg.snapshot != null) { programs.opencode.settings.snapshot = cfg.snapshot; })

    # ── Write ALL provider credentials to auth.json ───────────────────────────
    (mkIf hasAuthProviders {
      home.activation.opencodeAuthJson = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        verboseEcho "Setting up OpenCode auth.json for providers..."
        ${writeAuthJsonScript}
      '';
    })

  ]);
}
