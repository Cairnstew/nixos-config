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

  # JSON schemas shipped by the configured package (passthru.jsonschema in
  # nixpkgs). Home-manager's build-time `validateFiles` reads these through
  # cfg.package, which is why the wrapper below must re-export them.
  pkgSchema = (cfg.package.passthru or { }).jsonschema or { };

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
  # ~/.config/opencode and the shared background service, so running them
  # concurrently corrupts session state (see GOTCHAS.md). Matches
  # my.services.opencodeWeb.sessionGate on the system side.
  #
  # The gate runs before `exec`, so the wrapper shell is replaced by opencode
  # and the PID in the lock is preserved (exec keeps the PID). Stale locks
  # (dead PIDs) are cleaned by the web service's ExecStartPre. OPENCODE_ALLOW_CONCURRENT=1
  # bypasses both directions.
  opencodeGated = (pkgs.writeShellScriptBin "opencode" ''
    set -euo pipefail
    export PATH="${pkgs.systemd}/bin:${pkgs.gnugrep}/bin:${pkgs.coreutils}/bin:$PATH"

    ${optionalString cfg.serviceStaleGuard.enable ''
      # ── Stale-service guard (lazy half of my.programs.opencode.serviceStaleGuard) ──
      # Home-manager activation fingerprints the boot-time payload (local
      # plugins, custom tools, config layers) and drops a marker when it
      # changed. OpenCode 2 caches plugin modules for the whole life of the
      # background service and cannot re-resolve the retargeted store symlinks,
      # so the old service would keep running the previous plugin set (or fail
      # with "Cannot find module '/nix/store/…'" once that path is GC'd).
      # Stop it here, before dispatch, and let this invocation spawn a fresh
      # one — the rebuild itself never kills the session that ran it.
      if [[ -z "''${OPENCODE_SERVICE_STALE_GUARD_OFF:-}" && -e ${cfg.serviceStaleGuard.markerPath} ]]; then
        stale_first=""
        for a in "$@"; do
          case "$a" in
            -*) continue ;;
            *) stale_first="$a"; break ;;
          esac
        done
        case "''${1:-}" in
          -v|--version|-h|--help|--completions|--wizard)
            # Informational invocations never need the service.
            ;;
          *)
            if [ "$stale_first" = "service" ]; then
              # Explicit service management supersedes the marker — but only a
              # start/restart actually refreshes the payload.
              case "''${2:-}" in
                start|restart) rm -f ${cfg.serviceStaleGuard.markerPath} ;;
              esac
            elif [ -z "$stale_first" ] || [[ " run mini serve acp " == *" $stale_first "* ]]; then
              if ${pkgs.procps}/bin/pgrep -f 'serve --service' >/dev/null 2>&1; then
                ${pkgs.coreutils}/bin/timeout 10 ${opencodeWrapped}/bin/opencode service stop >/dev/null 2>&1 || true
                echo "opencode: stopped the stale background service (plugins/config changed since it started)" >&2
              fi
              rm -f ${cfg.serviceStaleGuard.markerPath}
            fi
            ;;
        esac
      fi
    ''}

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

    ${optionalString (cfg.modelFallback.chains != { }) ''
      # opencode v2 (2.2.1) removed the ROOT `--model` flag: yargs→effect-cli
      # now rejects it with `Unrecognized flag: --model in command opencode`
      # before dispatching anything, so appending it to every argv (the v1
      # behaviour) broke bare `opencode`, `opencode service status`, etc.
      # Model selection moved onto the subcommands that accept it:
      # `opencode run -m …` and `opencode mini -m …`. The full TUI takes its
      # model from opencode.json (agent/default model) plus its own picker.
      #
      # So inject ONLY for `run`/`mini`, and insert it AFTER the subcommand
      # token (never at the root). The usage-aware selector governs
      # programmatic runs; the bare TUI keeps the configured model. Opt out
      # with OPENCODE_MODEL_SELECT_OFF=1.
      if [ -z "''${OPENCODE_MODEL_SELECT_OFF:-}" ]; then
        # First positional arg (the subcommand) and its 1-based index,
        # skipping leading global flags.
        first=""
        first_idx=0
        i=0
        for a in "$@"; do
          i=$((i + 1))
          case "$a" in
            -*) continue ;;
            *) first="$a"; first_idx=$i; break ;;
          esac
        done
        # Skip when the user chose a model explicitly (-m / --model).
        explicit_model=0
        for a in "$@"; do
          case "$a" in
            -m|--model|--model=*|-m?*) explicit_model=1; break ;;
          esac
        done
        case "$first" in
          run|mini)
            if [ "$explicit_model" = 0 ] && m=$(opencode-model-select 2>/dev/null); then
              # Insert after the subcommand: `opencode run --model m …`
              set -- "''${@:1:$first_idx}" --model "$m" "''${@:$((first_idx + 1))}"
              echo "opencode: model-fallback selected $m" >&2
            fi
            ;;
        esac
      fi
    ''}

    # OpenCode 2 reads the HM declarative layers via env vars. Home Manager
    # sets these in home.sessionVariables, but non-login launches and the
    # already-running service can miss them; export them here so the wrapper
    # always loads the generated layers.
    if [ -r "$HOME/.config/opencode/home-manager.json" ]; then
      export OPENCODE_CONFIG="$HOME/.config/opencode/home-manager.json"
    fi
    if [ -r "$HOME/.config/opencode/home-manager-cli.json" ]; then
      export OPENCODE_CLI_CONFIG_CONTENT="$(cat "$HOME/.config/opencode/home-manager-cli.json")"
    fi

    exec ${opencodeWrapped}/bin/opencode "$@"
  '') // {
    # Home-manager detects the OpenCode major version via `lib.getVersion`.
    # A bare writeShellScriptBin reports 0.0.0, which makes HM treat this as
    # OpenCode 1 (warns that programs.opencode.cli is unsupported, and would
    # choose the V1 env var if mutableSettings were enabled).
    inherit (cfg.package) version;
    # Same reason: HM's programs.opencode.validateFiles asserts
    # cfg.package.passthru.jsonschema.*, and a writeShellScriptBin drops it.
    passthru = { jsonschema = pkgSchema; };
  };

  providers = import ./providers.nix { inherit lib cfg; };

  # Python environment with networkx for the nix-graph MCP server
  nixGraphPython = pkgs.python3.withPackages (ps: [ ps.networkx ]);

  # ── OpenCode 2 custom-tool bridge ─────────────────────────────────────────
  # OpenCode 2 no longer auto-loads home-manager's `~/.config/opencode/tools/`
  # V1 tool files. It registers custom tools through a plugin's
  # `ctx.tool.transform`. Generate a small loader plugin that imports each
  # rendered tool (a sibling under config/opencode/tools/) and adapts the V1
  # `{ description, args, execute }` export to the V2 `ToolInfo` shape.
  #
  # The generated plugin is rendered into ~/.config/opencode/plugins/ by the
  # pluginFiles block below. It resolves the live tool files at runtime from
  # $XDG_CONFIG_HOME/opencode/tools — the plugin itself is copied into the
  # Nix store, so a relative import would resolve next to the store copy.
  toolExt = _name: src:
    if !(builtins.isString src)
      && lib.hasSuffix ".js" (builtins.baseNameOf (builtins.toString src))
    then "js"
    else "ts";

  toolPlugin = pkgs.writeTextFile {
    name = "nixos-tools.ts";
    text = ''
      // Generated by modules/home/opencode/config.nix — do not edit.
      //
      // The plugin file is copied into the Nix store, so a relative import
      // (`../tools/x.ts`) resolves next to the *store copy*, not the live
      // config directory. Resolve the rendered tool files at runtime instead;
      // this also keeps the plugin working under a custom XDG_CONFIG_HOME.
      import { homedir } from "node:os";
      import { join } from "node:path";
      import { pathToFileURL } from "node:url";

      const configDir = () =>
        process.env.XDG_CONFIG_HOME
          ? join(process.env.XDG_CONFIG_HOME, "opencode")
          : join(homedir(), ".config", "opencode");

      const loadTool = async (name: string, ext: string) =>
        (await import(pathToFileURL(join(configDir(), "tools", `''${name}.''${ext}`)).href)).default;

      const toInput = (args: Record<string, unknown> | undefined) => ({
        type: "object",
        properties: args ?? {},
        additionalProperties: false,
      });

      export default {
        id: "nixos.tools",
        async setup(ctx: any) {
          const tools: Record<string, any> = {
            ${lib.concatStringsSep "\n" (lib.imap0
              (i: name: ''  "${name}": await loadTool("${name}", "${toolExt name cfg.tools.${name}}"),'')
              (lib.attrNames cfg.tools))}
          };

          await ctx.tool.transform((editor: any) => {
            for (const [name, tool] of Object.entries(tools) as Array<[string, any]>) {
              editor.add({
                name,
                description: tool.description ?? name,
                input: toInput(tool.args),
                async execute(input: any, context: any) {
                  const result = await tool.execute(input, context);
                  return {
                    content:
                      typeof result === "string"
                        ? result
                        : JSON.stringify(result, null, 2),
                  };
                },
              });
            }
          });
        },
      };
    '';
  };

  # ── V2 permission conversion ──────────────────────────────────────────────
  # V1 groups permission effects by tool name; V2 uses one ordered array of
  # { action, resource, effect } with last-match-wins (docs migrate-v1
  # §permissions). Action renames: bash→shell, task→subagent, write/patch→edit.
  v2PermissionAction = action:
    if action == "bash" then "shell"
    else if action == "task" then "subagent"
    else if action == "write" || action == "patch" then "edit"
    else action;

  # `tools` entries are tool-name actions with resource "*"; scalar action
  # values mean "*"; attrset values are resource globs.
  mkPermissionRules = perm:
    let
      toolRules = mapAttrsToList
        (tool: effect: { action = tool; resource = "*"; inherit effect; })
        (if (perm.tools or null) == null then { } else perm.tools);
      scalar = filterAttrs (n: v: n != "tools" && builtins.isString v) perm;
      pattern = filterAttrs (n: v: n != "tools" && builtins.isAttrs v) perm;
    in
    toolRules
    ++ builtins.concatLists (mapAttrsToList
      (name: effect: [{ action = v2PermissionAction name; resource = "*"; effect = effect; }])
      scalar)
    ++ builtins.concatLists (mapAttrsToList
      (name: rules: mapAttrsToList
        (resource: effect: { action = v2PermissionAction name; inherit resource effect; })
        rules)
      pattern);

  # Transform agent config to opencode.json format (native V2 `agents` entries)
  # Omit null/false values so only relevant fields appear in the JSON.
  # temperature/top_p are NOT emitted: V2 keeps agent `request.body` but never
  # sends it (docs migrate-v1 §agents) — set those on a model variant instead.
  mkAgentConfig = agentCfg:
    (lib.optionalAttrs (agentCfg.model != null) { model = agentCfg.model; })
    // (lib.optionalAttrs (agentCfg.mode != null) { mode = agentCfg.mode; })
    // (lib.optionalAttrs (agentCfg.description != null) { description = agentCfg.description; })
    // (lib.optionalAttrs (agentCfg.prompt != null) { system = agentCfg.prompt; })
    // (lib.optionalAttrs (agentCfg.steps != null) { steps = agentCfg.steps; })
    // (lib.optionalAttrs agentCfg.disable { disabled = true; })
    // (lib.optionalAttrs agentCfg.hidden { hidden = true; })
    // (lib.optionalAttrs (agentCfg.color != null) { color = agentCfg.color; })
    // (lib.optionalAttrs (agentCfg.permission != null) {
      permissions = mkPermissionRules agentCfg.permission;
    })
    // agentCfg.extraOptions;

  agentSettings = lib.optionalAttrs (cfg.agents != { } || cfg.smallModel != null) {
    agents = mapAttrs (_: mkAgentConfig) cfg.agents
      # V2 replaced `small_model` with the built-in `title` agent's model.
      // lib.optionalAttrs (cfg.smallModel != null) {
      title.model = cfg.smallModel;
    };
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

  # V2 groups servers under `mcp.servers`, inverts `enabled` to `disabled`, and
  # splits the old per-server timeout into catalog/execution (docs migrate-v1
  # §mcp). Non-integer timeouts are assumed to be V2 objects already.
  mkMcpServer = server:
    builtins.removeAttrs server [ "enabled" ]
    // lib.optionalAttrs (server.enabled or null == false) { disabled = true; }
    // lib.optionalAttrs (server ? timeout && builtins.isInt server.timeout) {
      timeout = { catalog = server.timeout; execution = server.timeout; };
    };

  mcpSettings = lib.optionalAttrs (cfg.mcp != { }) {
    mcp.servers = mapAttrs (_: mkMcpServer) cfg.mcp;
  };

  settingsWithMcp = recursiveUpdate settingsWithProviders mcpSettings;
  settingsWithReferences = recursiveUpdate settingsWithMcp referencesSettings;
  settingsWithPlugins = recursiveUpdate settingsWithReferences (
    lib.optionalAttrs (cfg.plugins != [ ]) { plugins = cfg.plugins; }
  );

  # ── External-directory permission rules ──────────────────────────────────
  # V2 permissions are one ordered array. These are the directories the agent
  # may read outside a project; a user-supplied `settings.permissions` wins.
  defaultExternalDirs = [
    "/nix/*"
    "/nix/store/**"
    "/nix/var/nix/**"
    "/run/current-system/**"
    "/run/agenix/**"
    "/etc/nixos/**"
    "/etc/xdg/waybar/**"
    "/etc/profiles/per-user/*/bin/*"
    "/tmp/*"
    "~/.cache/opencode/go-usage.json"
    "~/.local/share/opencode/worktree/**"
    "~/Projects/*"
    "~/Documents/*"
  ];
  externalDirRules = builtins.map
    (resource: { action = "external_directory"; inherit resource; effect = "allow"; })
    (defaultExternalDirs
      ++ map (entry: if builtins.isString entry then entry else entry.path) cfg.allowedDirs);
  rootPermissionsSettings =
    lib.optionalAttrs (!(cfg.settings ? permissions)) {
      permissions = externalDirRules;
    };

  mergedSettings = recursiveUpdate
    (recursiveUpdate (recursiveUpdate settingsWithPlugins agentSettings) policySettings)
    rootPermissionsSettings;

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
    # Native V2 key (2.2.x). `experimental.policies` still works but is
    # deprecated; V2 merges it into this list.
    policies = policyRules;
  };

  # ── Auth.json entries for ALL providers ────────────────────────────────────
  # Format matches what `/connect` command writes:
  # { "provider-name": { "type": "api", "key": "actual-key" } }

  # Build list of all providers that need auth.json entries
  allAuthProviders = lib.filter (p: p.keyFile != null) [
    # First-class providers
    { name = "opencode-go"; keyFile = cfg.opencode-go.keyFile; }
    { name = "opencode-zen"; keyFile = cfg.opencode-zen.keyFile; }
    { name = "opencode"; keyFile = cfg.opencode-zen.keyFile; }
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
            model = "opencode-go/deepseek-v4.1-flash";
            mode = "primary";
            steps = 10;
            permission = { edit = "deny"; bash = "deny"; };
          };
          explore = {
            description = "Quickly explore the codebase by searching files, patterns, and keywords (read-only)";
            model = "opencode-go/deepseek-v4.1-flash";
            mode = "subagent";
            permission = { edit = "deny"; bash = "deny"; };
          };
          build = {
            description = "Standard development agent with full tool access";
            model = "opencode-go/deepseek-v4.1-flash";
            mode = "primary";
            permission = {
              edit = "allow";
              bash = "allow";
            };
            # Required pre-final-summary self-improvement checkpoint
            # (SELF_IMPROVE=true in ./agents/build.md) — in-band, mechanical-guard
            # gated by tools/self-improve-commit.sh; no promote capability.
            # Kept out of the core description so the default agent stays
            # autonomy-preserving; the prompt only appends the pass.
            prompt = builtins.readFile ./agents/build.md;
          };
          researcher = {
            description = "In-depth web researcher — fetches and cross-references online docs, articles, and specifications";
            # Pinned explicitly (rather than left to fall through to the
            # parent/lead model) so research runs are reproducible and not
            # silently reshuffled by whatever the lead session happens to be on.
            # muse-spark-1.3-contributor: ~1M context, tool-capable, multimodal
            # (text/image/video/pdf/audio input) — a good fit for long
            # multi-page fetches and cross-referencing. Its reasoning effort is
            # pinned to "medium" by the model-level options block below.
            model = "opencode-go/muse-spark-1.3-contributor";
            mode = "subagent";
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
        # Individual key assignments (not lib.mkDefault on the whole attrset)
        # so they merge correctly with per-module overrides (mc-*, cv-*, etc.)
        # that also set individual keys. Using mkDefault on the whole attrset
        # causes individual-key definitions from other modules to replace it entirely.
        tools.tailscale-manager = ./tools/tailscale-manager.ts;
        tools.agenix-manager = ./tools/agenix-manager.ts;
        tools.nix-hosts = ./tools/nix-hosts.ts;
        tools.nix-eval = ./tools/nix-eval.ts;
        tools.nix-flake-check = ./tools/nix-flake-check.ts;
        tools.just = ./tools/just.ts;
        tools.opencode-models = ./tools/opencode-models.ts;
        tools.ci-monitor = ./tools/ci-monitor.ts;
        skills.git-repo-management = builtins.readFile ./skills/git-repo-management.md;
        skills.git-staging-commit-push = builtins.readFile ./skills/git-staging-commit-push.md;
        skills.nixos-configuration = builtins.readFile ./skills/nixos-configuration.md;
        skills.module-development = builtins.readFile ./skills/module-development.md;
        skills.deploy-workflow = builtins.readFile ./skills/deploy-workflow.md;
        skills.secrets-management = builtins.readFile ./skills/secrets-management.md;
        skills.testing-patterns = builtins.readFile ./skills/testing-patterns.md;
        skills.windows-integration = builtins.readFile ./skills/windows-integration.md;
        skills.docker-management = builtins.readFile ./skills/docker-management.md;
        skills.network-security = builtins.readFile ./skills/network-security.md;
        skills.model-selection = builtins.readFile ./skills/model-selection.md;
        skills.music-playlists = builtins.readFile ./skills/music-playlists.md;
        skills.mcp-server-management = builtins.readFile ./skills/mcp-server-management.md;
        skills.ci-monitoring = builtins.readFile ./skills/ci-monitoring.md;
        skills.module-extraction = builtins.readFile ./skills/module-extraction.md;
        skills.subagent-decomposition = builtins.readFile ./skills/subagent-decomposition.md;
        commands = {
          refactor-python = ./commands/refactor-python.md;
          nix-map = ./commands/nix-map.md;
          nix-refine = ./commands/nix-refine.md;
          nix-doc-audit = ./commands/nix-doc-audit.md;
          nix-net-audit = ./commands/nix-net-audit.md;
          shopping-research = ./commands/shopping-research.md;
          git-commit-push = ./commands/git-commit-push.md;
          git-pull-master = ./commands/git-pull-master.md;
          # Repo-agnostic: audits and improves the data pipeline of whatever repo
          # it is invoked in, in an isolated worktree. See the command's own
          # hard rules for the base-branch and raw-data protections.
          data-quality = ./commands/data-quality.md;
        };
        pluginFiles = lib.mkDefault ({
          copylast = ./plugins/copylast.ts;
          self-improve-guard = ./plugins/self-improve-guard.ts;
        } // lib.optionalAttrs (cfg.tools != { }) {
          # V2 registers custom tools through a plugin (see toolPlugin above).
          nixos-tools = toolPlugin;
        });
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
        mcp.pdf-mcp = {
          enabled = true;
          type = "local";
          command = [
            "${pkgs.callPackage ../../../packages/pdf-mcp {}}/bin/pdf-mcp"
          ];
          timeout = 30000;
        };
        mcp.terraform = {
          enabled = true;
          type = "local";
          command = [ "terraform-mcp-server" "stdio" ];
          timeout = 120000;
        };
        mcp.ieee = lib.mkIf (config.age.secrets ? "ieee-api-key") {
          enabled = true;
          type = "local";
          command = [ "npx" "-y" "danieltyukov-ieee-mcp" ];
          environment = {
            IEEE_API_KEY = "{file:${config.age.secrets.ieee-api-key.path}}";
          };
          timeout = 120000;
        };
        mcp.steam = {
          enabled = true;
          type = "local";
          command = [ "npx" "-y" "@praeses/steam-mcp" ];
          timeout = 120000;
        };
        # Official GitHub MCP server (github/github-mcp-server, Go binary).
        # File tree browsing via repos toolset, issues, PRs, actions, code security.
        # Token read from agenix at runtime via {file:...} substitution.
        mcp.github = {
          enabled = true;
          type = "local";
          command = [ "${pkgs.github-mcp-server}/bin/github-mcp-server" "stdio" ];
          environment = {
            GITHUB_PERSONAL_ACCESS_TOKEN = "{file:/run/agenix/github-token}";
            GITHUB_TOOLSETS = "repos,issues,pull_requests,actions,code_security,context";
          };
          timeout = 120000;
        };
        # Knowledge Graph Memory — official MCP reference implementation.
        # Persistent JSONL storage so the graph survives rebuilds.
        mcp.memory = {
          enabled = true;
          type = "local";
          command = [ "${pkgs.mcp-server-memory}/bin/mcp-server-memory" ];
          environment = {
            MEMORY_FILE_PATH = "/home/seanc/.local/share/opencode/memory.jsonl";
          };
          timeout = 120000;
        };
        # Apify hosted MCP server (https://mcp.apify.com), scoped to the
        # Wattpad Story Scraper actor (easyapi/wattpad-story-scraper) plus the
        # generic actor-details tool. Remote + OAuth: sign in on first use with
        # `opencode mcp auth apify` — no API token belongs in config. Add more
        # actors to the `tools=` query param as needed.
        mcp.apify = {
          enabled = true;
          type = "remote";
          url = "https://mcp.apify.com/?tools=fetch-actor-details,easyapi/wattpad-story-scraper";
          timeout = 30000;
        };
      };
    }

    # ── Subagent roster ──────────────────────────────────────────────────
    # Parallel work is done with opencode's built-in `subagent` tool instead
    # of the retired opencode-ensemble plugin. Subagents share this working
    # tree (there are no worktrees and no merge step), so only ONE writer may
    # run at a time; scout/planner/reviewer are read-only and safe to fan out.
    # Guidance: skills/subagent-decomposition.md.
    {
      my.programs.opencode.agents = lib.mkDefault {
        scout = {
          description = "Read-only codebase reconnaissance — files, patterns, call sites, subsystem mapping";
          mode = "subagent";
          model = null;
          permission = {
            edit = "deny";
            bash = "deny";
          };
        };
        planner = {
          description = "Read-only planning — turn recon findings into an ordered task list with file ownership and validation steps";
          mode = "subagent";
          model = null;
          permission = {
            edit = "deny";
            bash = "deny";
          };
        };
        builder = {
          description = "Single-file-scoped implementer — ONE writer at a time; commit before the next builder starts";
          mode = "subagent";
          model = null;
          permission = { edit = "allow"; bash = "allow"; };
        };
        qa = {
          description = "Write tests, fixtures, and regression coverage, then run the suite and report failures verbatim";
          mode = "subagent";
          model = null;
          permission = { edit = "allow"; bash = "allow"; };
        };
        reviewer = {
          description = "Read-only diff review — correctness, missed tests, risky behavior, scope creep";
          mode = "subagent";
          model = null;
          permission = {
            edit = "deny";
            bash = "deny";
          };
        };
      };
    }

    # Base opencode config
    {
      programs.opencode = {
        enable = true;
        package = opencodeGated;

        # OpenCode 2 writes cli.json/opencode.json itself. Let Home Manager
        # write home-manager-*.json and inject them via OPENCODE_CONFIG /
        # OPENCODE_CLI_CONFIG_CONTENT instead of managing the app-owned files;
        # otherwise every switch tries to back up cli.json and collides on the
        # existing cli.json.backup.
        mutableSettings = lib.mkDefault true;

        enableMcpIntegration = cfg.enableMcpIntegration;
        context = cfg.context;
        commands = cfg.commands;
        themes = cfg.themes;
        # Schema-validate the generated home-manager.json / -cli.json at build
        # time (check-jsonschema). Only enabled when the package ships the
        # schemas (pkgSchema), so a bare wrapper still evaluates.
        validateFiles = {
          config = lib.mkDefault (pkgSchema ? config);
          cli = lib.mkDefault (pkgSchema ? cli);
        };
        # OpenCode 2.3.0 defaults `session.verbosity` to "low", which collapses
        # each run of tool calls into one activity row. Pin "medium" so tool
        # calls stay visible; hosts override via my.programs.opencode.cli.
        cli = lib.mkDefault (recursiveUpdate { session.verbosity = "medium"; } cfg.cli);
        skills = cfg.skills;
        tools = cfg.tools;
        extraPackages = cfg.extraPackages
          ++ [ pkgs.terraform-mcp-server pkgs.nodejs ];
        settings = mergedSettings;
      };
    }

    # OpenCode 2 installs are owned by Nix; the default "notify" update mode
    # only ever tells the user about a release they cannot install in place.
    { programs.opencode.settings.update = lib.mkDefault "disable"; }

    # ── Default model context window + reasoning effort ─────────────────────
    # opencode's `limit.context` caps how many context tokens are sent to the
    # model; the schema requires `output` alongside it. The same per-model
    # block carries `settings.reasoningEffort` — the model's default thinking
    # effort everywhere it is dispatched (agents AND fallback-chain rungs),
    # which per-agent config can override. Allowed effort values come from
    # models.dev `reasoning_options`: deepseek-v4.1-flash is low|high|max,
    # muse-spark-1.3-contributor is minimal|low|medium|high|xhigh. Hosts
    # override via my.programs.opencode.settings.
    {
      programs.opencode.settings.providers.opencode-go.models."deepseek-v4-flash".limit =
        lib.mkDefault {
          context = 500000;
          output = 8192;
        };
      programs.opencode.settings.providers.opencode-go.models."deepseek-v4.1-flash".limit =
        lib.mkDefault {
          context = 500000;
          output = 8192;
        };
      programs.opencode.settings.providers.opencode-go.models."deepseek-v4.1-flash".settings.reasoningEffort =
        lib.mkDefault "high";
      programs.opencode.settings.providers.opencode-go.models."muse-spark-1.3-contributor".limit =
        lib.mkDefault {
          context = 500000;
          output = 8192;
        };
      programs.opencode.settings.providers.opencode-go.models."muse-spark-1.3-contributor".settings.reasoningEffort =
        lib.mkDefault "medium";
    }

    # ── Local plugin files ──────────────────────────────────────────────────
    # Render each plugin into ~/.config/opencode/plugins/. Source paths ending
    # in `.ts` keep a `.ts` extension so opencode loads them as TypeScript;
    # everything else (and inline text) renders as `.js`. Derivation sources
    # render as `source` too — builtins.isPath is false for derivations, so
    # test for them explicitly.
    (mkIf (cfg.pluginFiles != { }) {
      home.file = builtins.listToAttrs (mapAttrsToList
        (name: src:
          let
            isPathLike =
              builtins.isPath src
              # Derivations are attrset-valued (builtins.typeOf == "set");
              # detect them by their outPath attribute rather than isPath,
              # which is false for them.
              || (src ? outPath);
            ext =
              if isPathLike && lib.hasSuffix ".ts" (builtins.baseNameOf (builtins.toString src))
              then ".ts"
              else ".js";
          in
          {
            name = ".config/opencode/plugins/${name}${ext}";
            value =
              if isPathLike
              then { source = src; }
              else { text = src; };
          })
        cfg.pluginFiles);
    })

    # ── Stale background-service marker ─────────────────────────────────────
    # OpenCode 2 loads plugins, custom tools and the config layers exactly once
    # per background service, and caches plugin modules for that process's
    # lifetime. Home-manager renders all of them as store symlinks, so a switch
    # retargets them: the running service then keeps executing the previous
    # plugin set, or (once the old store path is garbage collected) logs
    # "failed to load plugin: Cannot find module '/nix/store/…'" and runs
    # without nixos-tools/self-improve-guard entirely. It cannot recover from
    # inside; only a new process loads the new files.
    #
    # Fingerprint the files the service reads at boot by content (an unchanged
    # payload keeps the same fingerprint even though the rest of the tree
    # moves) and drop a marker on change. The CLI wrapper (opencodeGated above)
    # consumes it on the next session start. Deliberately NOT a
    # stop-during-activation: `nixos-rebuild` is routinely run from inside an
    # opencode session, and activation killing the service would kill that
    # session (see AGENT.md's note on this trap).
    (mkIf cfg.serviceStaleGuard.enable {
      home.activation.opencodeServiceStaleMarker =
        lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          verboseEcho "Checking OpenCode background-service payload..."

          fingerprint=$(
            {
              # Hash contents, not resolved targets: a home-manager symlink and
              # a hand-placed real file must both be detected when they change,
              # and including the file name makes renames/additions visible.
              for f in ${config.home.homeDirectory}/.config/opencode/plugins/* \
                       ${config.home.homeDirectory}/.config/opencode/tools/*; do
                [ -f "$f" ] || continue
                printf '%s %s\n' "''${f##*/}" \
                  "$(${pkgs.coreutils}/bin/sha256sum < "$f" | ${pkgs.coreutils}/bin/cut -d' ' -f1)"
              done
              for f in ${config.home.homeDirectory}/.config/opencode/home-manager.json \
                       ${config.home.homeDirectory}/.config/opencode/home-manager-cli.json \
                       ${config.home.homeDirectory}/.config/opencode/model-fallback.json \
                       ${config.home.homeDirectory}/.config/opencode/self-improve.json; do
                [ -f "$f" ] || continue
                printf '%s %s\n' "''${f##*/}" \
                  "$(${pkgs.coreutils}/bin/sha256sum < "$f" | ${pkgs.coreutils}/bin/cut -d' ' -f1)"
              done
            } | ${pkgs.coreutils}/bin/sort \
              | ${pkgs.coreutils}/bin/sha256sum \
              | ${pkgs.coreutils}/bin/cut -d' ' -f1
          )

          state=${cfg.serviceStaleGuard.statePath}
          marker=${cfg.serviceStaleGuard.markerPath}
          mkdir -p "$(dirname "$state")"
          if [ "$fingerprint" != "$(cat "$state" 2>/dev/null || true)" ]; then
            printf '%s\n' "$fingerprint" > "$state"
            : > "$marker"
            verboseEcho "  plugins/config changed since the service started:"
            verboseEcho "  it will be restarted on the next opencode session start"
            verboseEcho "  (or now with: opencode service restart)"
          fi
        '';
    })

    # External-directory permissions are emitted as V2 `permissions` rules in
    # `mergedSettings` (see rootPermissionsSettings above); the old V1
    # `settings.permission` map is no longer emitted.

    # ── Ollama: auto-select default model if one is tagged ──────────────────
    (mkIf (providers.defaultOllamaModel != null) {
      programs.opencode.settings.model = lib.mkDefault "ollama/${providers.defaultOllamaModel}";
    })

    # ── Shorthands (plain assignment = priority 100, overrides mkDefault) ───
    (mkIf (cfg.model != null) { programs.opencode.settings.model = cfg.model; })
    (mkIf (cfg.share != null) { programs.opencode.settings.share = cfg.share; })
    # V2 renamed `autoupdate` to `update`. `true` maps to "notify", not V2's
    # "auto": this install is Nix-owned, so nothing may overwrite the store.
    (mkIf (cfg.autoupdate != null) {
      programs.opencode.settings.update =
        if cfg.autoupdate == false then "disable" else "notify";
    })
    (mkIf (cfg.defaultAgent != null) { programs.opencode.settings.default_agent = cfg.defaultAgent; })
    (mkIf (cfg.shell != null) { programs.opencode.settings.shell = cfg.shell; })
    (mkIf (cfg.snapshot != null) { programs.opencode.settings.snapshots = cfg.snapshot; })

    # ── Write ALL provider credentials to auth.json ───────────────────────────
    (mkIf hasAuthProviders {
      home.activation.opencodeAuthJson = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        verboseEcho "Setting up OpenCode auth.json for providers..."
        ${writeAuthJsonScript}
      '';
    })

    # ── Efficiency lens dependency ───────────────────────────────────────────
    # The self-improvement checkpoint's efficiency lens queries opencode.db
    # via sqlite3 CLI; without it the lens silently no-ops.
    {
      home.packages = [ pkgs.sqlite ];
    }

    # ── General-provider credential toggle ───────────────────────────────────
    # opencode-zen.keyFile is a single static Nix option, so swapping between
    # opencode-token / opencode-token-2 meant a full nixos-rebuild. auth.json is
    # merged (not overwritten) by writeAuthJsonScript, so `opencode-key-toggle`
    # can flip the `opencode` + `opencode-zen` entries in place.
    {
      home.packages = [
        (pkgs.writeShellApplication {
          name = "opencode-key-toggle";
          # systemd for `systemctl --user show -p MainPID` (waybar repaint);
          # procps is deliberately NOT used — see waybar_reload() in the script
          # for why name/pgrep-based signalling does not work here.
          runtimeInputs = with pkgs; [ jq coreutils systemd ];
          text = builtins.readFile ./key-toggle.sh;
        })
      ];
    }

    # ── Self-improve commit-helper rate caps (mechanical, Decision 3) ────────
    # Written for tools/self-improve-commit.sh to read; null = uncapped.
    {
      home.file.".config/opencode/self-improve.json".text = builtins.toJSON {
        maxCommitsPerSession = cfg.selfImprove.maxCommitsPerSession;
        maxCommitsPerDay = cfg.selfImprove.maxCommitsPerDay;
        efficiencyLensMinToolCalls = cfg.selfImprove.efficiencyLensMinToolCalls;
        efficiencyLensMinCost = cfg.selfImprove.efficiencyLensMinCost;
      };
    }

    # ── Guard: tools must be files, not path-string stubs ─────────────────────
    # my.programs.opencode.tools renders a path via home.file.source (real file)
    # but a string via .text (literal content). A caller that writes
    # `tools.x = "${someInput}/tools/x.ts"` (interpolated string) installs an
    # 85-byte file containing only the store path; opencode then dies parsing it
    # as TypeScript ("Invalid flag" regex errors). Fail eval instead.
    {
      assertions = [{
        assertion = lib.all
          (v:
            !(builtins.isString v)
            || !(lib.hasPrefix "/nix/store/" v)
            || builtins.stringLength v > 200)
          (lib.attrValues cfg.tools);
        message = ''
          my.programs.opencode.tools contains a store-path string stub: one or
          more tool values are bare "/nix/store/..." strings with no real content
          (likely "''${input}/tools/x.ts" interpolation). Pass real path values —
          e.g. /. + builtins.unsafeDiscardStringContext (input.outPath + "/tools/x.ts")
          (plain input.outPath + "/x" is still a *string* on Nix 2.34; only the
          /. + unsafeDiscardStringContext construct reaches the source = src;
          branch) so home-manager copies the file instead of writing the path
          string as literal text.
        '';
      }];
    }

  ]);
}
