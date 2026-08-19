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

  # Terminal session gate: when enabled, a terminal opencode refuses to start
  # while the opencode web (browser) service is running, and otherwise writes a
  # PID lock that the web service checks before starting. Both sessions share
  # ~/.config/opencode and the ensemble DB, so running them concurrently
  # corrupts team orchestration (see GOTCHAS.md). Matches
  # my.services.opencodeWeb.sessionGate on the system side.
  #
  # The gate runs before `exec`, so the wrapper shell is replaced by opencode
  # and the PID in the lock is preserved (exec keeps the PID). Stale locks
  # (dead PIDs) are cleaned by the web service's ExecStartPre. OPENCODE_ALLOW_CONCURRENT=1
  # bypasses both directions.
  opencodeGated = pkgs.writeShellScriptBin "opencode" ''
    set -euo pipefail
    export PATH="${pkgs.systemd}/bin:${pkgs.gnugrep}/bin:${pkgs.coreutils}/bin:$PATH"

    ${optionalString cfg.sessionGate.enable ''
      if [[ -z "''${OPENCODE_SESSION_GATED:-}" ]]; then
        export OPENCODE_SESSION_GATED=1
        if [[ -z "''${OPENCODE_ALLOW_CONCURRENT:-}" ]]; then
          # Refuse to start while any opencode web (browser) service is active.
          if systemctl list-units 'opencode-web-*.service' --state=active --no-legend --no-pager | grep -q .; then
            echo "opencode: refusing to start — the opencode web (browser) session is running." >&2
            echo "  Stop it first:  sudo systemctl stop 'opencode-web-*.service'" >&2
            echo "  or force:       OPENCODE_ALLOW_CONCURRENT=1 opencode" >&2
            exit 1
          fi
          # Write the terminal PID lock for the web service's ExecStartPre.
          lock=${cfg.sessionGate.lockPath}
          mkdir -p "$(dirname "$lock")"
          echo $$ > "$lock"
        fi
      fi
    ''}

    exec ${opencodeWrapped}/bin/opencode "$@"
  '';

  providers = import ./providers.nix { inherit lib cfg; };

  # Python environment with networkx for the nix-graph MCP server
  nixGraphPython = pkgs.python3.withPackages (ps: [ ps.networkx ]);

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
      permission = filterAttrs (_: v: v != null)
        {
          inherit (agentCfg.permission)
            read edit glob grep list bash task external_directory
            lsp skill todowrite webfetch websearch question doom_loop;
        }
      // (lib.optionalAttrs (agentCfg.permission.tools != null) agentCfg.permission.tools);
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
    (builtins.map
      (provider: {
        effect = "allow";
        action = "provider.use";
        resource = provider;
      })
      cfg.policies.allowedProviders)
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
            permission = {
              edit = "allow";
              bash = "allow";
              # No-human auto-improvement: build may call learning_promote to
              # validate/reject learnings (never over a fresh proposal it just
              # recorded itself) — dispatch the
              # three-role triage team to re-derive verdicts first, then promote
              # only on their unanimous, harness-confirmed agreement. Auto-merge
              # applied learnings into the base branch; git history is the
              # rollback net.
              tools = { "goals_learning_promote" = "allow"; };
            };
            # Required pre-final-summary self-improvement checkpoint
            # (SELF_IMPROVE=true in ./agents/build.md) — proposal via
            # learning_append, promotion only after team-approved triage.
            # Kept out of the core description so the default agent stays
            # autonomy-preserving; the prompt only appends the pass.
            prompt = builtins.readFile ./agents/build.md;
          };
          researcher = {
            description = "In-depth web researcher — fetches and cross-references online docs, articles, and specifications";
            mode = "subagent";
            temperature = 0.2;
            prompt = builtins.readFile ./agents/researcher.md;
            permission = {
              webfetch = "allow";
              read = "allow";
              glob = "allow";
              grep = "allow";
              list = "allow";
              question = "allow";
              # Read-only everywhere except its own definition file, so the
              # optional self-improvement pass (SELF_IMPROVE=true) can update it.
              edit = { "*agents/researcher.md" = "allow"; };
              bash = "deny";
            };
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
          network-security = builtins.readFile ./skills/network-security.md;
        };
        commands = {
          copy-last = ./commands/copylast.md;
          refactor-python = ./commands/refactor-python.md;
          nix-map = ./commands/nix-map.md;
          nix-refine = ./commands/nix-refine.md;
          nix-doc-audit = ./commands/nix-doc-audit.md;
          nix-net-audit = ./commands/nix-net-audit.md;
          shopping-research = ./commands/shopping-research.md;
          triage-review = ./commands/triage-review.md;
          learning-promote = ./commands/learning-promote.md;
        };
        pluginFiles = lib.mkDefault {
          copylast = ./plugins/copylast.ts;
          triage-capture = ./plugins/triage-capture.ts;
          self-improve-guard = ./plugins/self-improve-guard.ts;
        };
        mcp.nix-graph = {
          enabled = true;
          type = "local";
          command = [
            "${nixGraphPython}/bin/python3"
            "${../../../tools/nix-graph/mcp_server.py}"
            "--graph"
            "${../../../tools/nix-graph/graph.json}"
          ];
          timeout = 120000;
        };
      };
    }

    # ── Ensemble skills & sub-agents ──────────────────────────────────────
    {
      my.programs.opencode.skills = lib.mkDefault {
        opencode-ensemble = builtins.readFile ./skills/opencode-ensemble.md;
        nixos-ensemble-decomposition = builtins.readFile ./skills/nixos-ensemble-decomposition.md;
      };
      my.programs.opencode.agents = lib.mkDefault {
        scout = {
          description = "Quickly explore the codebase by searching files, patterns, and keywords (read-only) — ensemble scout role";
          mode = "subagent";
          model = null;
          temperature = 0.1;
          permission = {
            edit = "deny";
            bash = "deny";
            # Decision 1 defense-in-depth: triage/scout roles must never reach
            # learning_promote. MCP tools are named <server>_<tool> in opencode.
            tools = { "goals_learning_promote" = "deny"; };
          };
        };
        qa = {
          description = "Write tests, fixtures, and regression coverage — ensemble QA role";
          mode = "subagent";
          model = null;
          permission = { edit = "allow"; bash = "allow"; };
        };
        reviewer = {
          description = "Review diffs for correctness, missed tests, and risky behavior — ensemble reviewer role";
          mode = "subagent";
          model = null;
          temperature = 0.1;
          permission = {
            edit = "deny";
            bash = "deny";
            # Decision 1 defense-in-depth: same as scout — no learning_promote.
            tools = { "goals_learning_promote" = "deny"; };
          };
        };
        # ── Tier 1 triage roles (observe-only verdicts) ──────────────────
        # Three independent reviewers that each call goals_learning_review on a
        # proposed learning. All are read-only (edit/bash denied) and cannot
        # reach learning_promote (Decision 1 defense-in-depth). They differ only
        # in review stance: a skeptical scout, a verification-focused QA, and an
        # adversarial critic. Verdicts land in review_verdicts via learning_review;
        # the triage-capture plugin back-fills rederivation/confidence from the
        # session transcript, so the roles are never asked to self-report.
        scout-skeptical = {
          description = "Skeptical read-only scout triage: re-derive the learning's evidence and render an agree/disagree/uncertain verdict via goals_learning_review";
          mode = "subagent";
          model = null;
          temperature = 0.1;
          permission = {
            edit = "deny";
            bash = "deny";
            tools = { "goals_learning_promote" = "deny"; };
          };
        };
        qa-verification = {
          description = "Read-only QA triage: verify the learning's evidence still holds and render an agree/disagree/uncertain verdict via goals_learning_review";
          mode = "subagent";
          model = null;
          temperature = 0.1;
          permission = {
            edit = "deny";
            bash = "deny";
            tools = { "goals_learning_promote" = "deny"; };
          };
        };
        adversarial = {
          description = "Read-only adversarial triage: attempt to falsify the learning's evidence and render an agree/disagree/uncertain verdict via goals_learning_review";
          mode = "subagent";
          model = null;
          temperature = 0.2;
          permission = {
            edit = "deny";
            bash = "deny";
            tools = { "goals_learning_promote" = "deny"; };
          };
        };
        # ── Full-auto promoter (promote-capable) ───────────────────────────
        # Runs the promotion loop headlessly: dispatch the three triage reviewers
        # to re-derive evidence, then learning_promote only on unanimous,
        # harness-re-derived agreement, applying each accepted learning with an
        # isolated commit and auto-merging it into the base branch. Successful
        # review triage teams may also approve learnings whose proposals came
        # from other sessions (a session must never promote its OWN new
        # proposal). It has edit/bash because it applies+commits+merges each
        # accepted learning; git history is the audit/rollback net.
        learning-promoter = {
          description = "Headless automated promotion of proposed agent learnings: dispatch the three triage reviewers to re-derive evidence, then learning_promote only on unanimous re-derivation-gated agreement, applying each accepted learning as an isolated commit, auto-merging into the base branch";
          mode = "primary";
          model = "opencode-go/deepseek-v4-flash";
          temperature = 0.1;
          prompt = builtins.readFile ./agents/learning-promoter.md;
          permission = {
            edit = "allow";
            bash = "allow";
            tools = { "goals_learning_promote" = "allow"; };
          };
        };
      };
    }

    # Base opencode config
    {
      programs.opencode = {
        enable = true;
        package = opencodeGated;
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

    # ── Default model context window ────────────────────────────────────────
    # opencode's `limit.context` caps how many context tokens are sent to the
    # model; the schema requires `output` alongside it. Default applies to the
    # shared default model (DeepSeek V4 via opencode-go); hosts override via
    # my.programs.opencode.settings.
    {
      programs.opencode.settings.provider.opencode-go.models."deepseek-v4-flash".limit =
        lib.mkDefault {
          context = 500000;
          output = 8192;
        };
    }

    # ── Ensemble plugin config → ~/.config/opencode/ensemble.json ─────────
    (mkIf (cfg.ensemble != null) {
      home.file.".config/opencode/ensemble.json" = {
        text = builtins.toJSON cfg.ensemble;
      };
    })

    # ── Local plugin files ──────────────────────────────────────────────────
    # Render each plugin into ~/.config/opencode/plugins/. Source paths ending
    # in `.ts` keep a `.ts` extension so opencode loads them as TypeScript;
    # everything else (and inline text) renders as `.js`.
    (mkIf (cfg.pluginFiles != { }) {
      home.file = builtins.listToAttrs (mapAttrsToList
        (name: src:
          let
            ext =
              if builtins.isPath src && lib.hasSuffix ".ts" (builtins.baseNameOf src)
              then ".ts"
              else ".js";
          in
          {
            name = ".config/opencode/plugins/${name}${ext}";
            value =
              if builtins.isPath src
              then { source = src; }
              else { text = src; };
          })
        cfg.pluginFiles);
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

    # ── Learning-promoter watcher (v2 — opencode serve, no tmux) ──────────────
    (mkIf cfg.learningPromoterWatcher.enable {
      home.packages = [
        (pkgs.python3.withPackages (_: [ ]))
        pkgs.curl
      ];

      home.file.".local/share/opencode/learning-promoter-launcher.py".source =
        pkgs.runCommand "learning-promoter-launcher.py" { } ''
          cp ${./tools/learning-promoter-launcher.py} "$out"
          chmod +x "$out"
        '';

      # Persistent headless opencode server for the promoter agent.
      # The watcher sends commands via `opencode run --attach` — no tmux needed.
      systemd.user.services.opencode-serve = {
        Unit = {
          Description = "Headless opencode server for automated agent workflows";
          After = [ "graphical-session.target" ];
        };
        Service = {
          Type = "simple";
          WorkingDirectory = cfg.learningPromoterWatcher.repoDir;
          ExecStart = "${cfg.package}/bin/opencode serve --port ${toString cfg.learningPromoterWatcher.servePort} --hostname 127.0.0.1";
          Restart = "on-failure";
          RestartSec = 5;
          Environment = [
            "OPENCODE_SERVER_PASSWORD=${cfg.learningPromoterWatcher.serverPassword}"
          ];
          # Resource limits to prevent memory leak from crashing the host (#20695)
          MemoryMax = "2G";
          MemoryHigh = "1536M";
          CPUQuota = "200%";
          TasksMax = 256;
        };
      };

      systemd.user.services.learning-promoter-watcher = {
        Unit = {
          Description = "Learning-promoter watcher — dispatches promoter when proposed learnings exist";
          After = [ "opencode-serve.service" ];
          Requires = [ "opencode-serve.service" ];
        };
        Service = {
          Type = "oneshot";
          ExecStart = "${pkgs.python3}/bin/python3 ${config.home.homeDirectory}/.local/share/opencode/learning-promoter-launcher.py";
          Environment = [
            "GOALS_DB=${cfg.learningPromoterWatcher.goalsDb}"
            "REPO_DIR=${cfg.learningPromoterWatcher.repoDir}"
            "OPENCODE_SERVER_URL=http://127.0.0.1:${toString cfg.learningPromoterWatcher.servePort}"
            "PROMOTION_TIMEOUT=${toString cfg.learningPromoterWatcher.promotionTimeout}"
            "STALENESS_THRESHOLD=${toString cfg.learningPromoterWatcher.stalenessThreshold}"
            "COMMAND_TIMEOUT=${toString cfg.learningPromoterWatcher.commandTimeout}"
            "STATE_DIR=${config.home.homeDirectory}/.local/share/opencode"
          ];
        };
      };

      systemd.user.timers.learning-promoter-watcher = {
        Unit = {
          Description = "Periodically check for proposed learnings and dispatch promoter";
        };
        Timer = {
          OnBootSec = cfg.learningPromoterWatcher.checkInterval;
          OnUnitActiveSec = cfg.learningPromoterWatcher.checkInterval;
          Persistent = true;
          RandomizedDelaySec = "1min";
        };
        Install = {
          WantedBy = [ "timers.target" ];
        };
      };
    })

  ]);
}
