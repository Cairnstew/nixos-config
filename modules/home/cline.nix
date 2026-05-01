# modules/home/cline.nix
{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib)
    literalExpression
    mkEnableOption
    mkIf
    mkOption
    optionalAttrs
    types
    ;

  cfg = config.my.programs.cline;

  # Node 22 required by kanban and cline CLI.
  nodejs = pkgs.nodejs_22;

  # Find the first model flagged as the cline default.
  defaultModelTag = lib.findFirst
    (tag: cfg.ollamaModels.${tag}.cline_default or false)
    null
    (lib.attrNames cfg.ollamaModels);

  usingOllama = cfg.ollamaModels != {};

  # Prefer the flagged Ollama model, then the explicit model option.
  clineDefaultModel =
    if defaultModelTag != null
    then defaultModelTag
    else cfg.model;

  # ---------------------------------------------------------------------------
  # VS Code settings
  #
  # Uses the "ollama" provider — talks directly to Ollama's native API.
  # Do NOT switch to "openai" here: that provider ignores baseUrl entirely
  # and always hits api.openai.com, causing auth failures with local models.
  # ---------------------------------------------------------------------------
  clineVSCodeSettings = {
    "cline.apiProvider"   = "ollama";
    "cline.ollamaBaseUrl" = cfg.ollamaBaseURL;  # no /v1 — ollama provider adds it
    "cline.ollamaModelId" = clineDefaultModel;
  } // cfg.settings;

  # ---------------------------------------------------------------------------
  # providers.json
  #
  # Copied (not symlinked) so Cline can write back at runtime.
  # Always overwritten on home-manager switch so Nix stays authoritative
  # — Cline regularly rewrites this file when the user switches models in the UI.
  # ---------------------------------------------------------------------------
  clineProvidersFile = pkgs.writeText "cline-providers.json" (
    builtins.toJSON {
      version          = 1;
      lastUsedProvider = "ollama";
      providers = {
        ollama = {
          settings = {
            provider = "ollama";
            model    = clineDefaultModel;
            baseUrl  = cfg.ollamaBaseURL;  # no /v1 — ollama provider adds it
            apiKey   = "ollama";
          };
          updatedAt   = "2026-04-30T01:00:00.000Z";
          tokenSource = "manual";
        };
      };
    }
  );

  # ---------------------------------------------------------------------------
  # MCP settings helpers
  #
  # Our local MCP bridge (supergateway wrapping ollama-mcp-server) uses SSE
  # transport and serves at /sse. Always use type = "sse" for supergateway.
  # Use "streamableHttp" only for hosted services that explicitly support it
  # (e.g. Linear). Never use "streamableHttp" + /mcp for supergateway — it
  # will return garbage and cause "expected string, received undefined" errors
  # in Cline's tool call parser.
  # ---------------------------------------------------------------------------
  mcpServersObj = lib.mapAttrs (_name: srv:
    { inherit (srv) type url; }
    // lib.optionalAttrs (srv.env     != {}) { inherit (srv) env; }
    // lib.optionalAttrs (srv.headers != {}) { inherit (srv) headers; }
  ) cfg.mcp.servers;

  clineMcpSettingsFile = pkgs.writeText "cline-mcp-settings.json" (
    builtins.toJSON { mcpServers = mcpServersObj; }
  );

  # Seed an empty-but-valid OAuth file so Cline doesn't error on first read.
  # Never overwritten after creation so Cline's own OAuth tokens are preserved.
  clineMcpOAuthSettingsFile = pkgs.writeText "cline-mcp-oauth-settings.json" (
    builtins.toJSON {
      servers = lib.mapAttrs (_name: _srv: {}) cfg.mcp.servers;
    }
  );

  hasMcpServers = cfg.mcp.servers != {};

  # ---------------------------------------------------------------------------
  # Health-check script
  # SSE servers: HTTP GET to base URL.
  # streamableHttp servers: POST MCP initialize message.
  # ---------------------------------------------------------------------------
  mcpHealthScript = pkgs.writeShellScriptBin "cline-mcp-health" ''
    set -euo pipefail
    ok=0
    fail=0

    check_get() {
      local name="$1" url="$2"
      local base
      base=$(echo "$url" | ${pkgs.gnused}/bin/sed 's|/sse$||;s|/mcp$||')
      printf "  %-30s " "$name"
      local http_code
      http_code=$(${pkgs.curl}/bin/curl -s -o /dev/null -w "%{http_code}" \
        --max-time 5 --connect-timeout 3 "$base" 2>/dev/null || echo "000")
      if [[ "$http_code" == "000" ]]; then
        echo "✗  UNREACHABLE (connection refused or timeout)"
        fail=$((fail + 1))
      elif [[ "$http_code" -ge 200 && "$http_code" -lt 500 ]]; then
        echo "✓  OK (HTTP $http_code)"
        ok=$((ok + 1))
      else
        echo "✗  ERROR (HTTP $http_code)"
        fail=$((fail + 1))
      fi
    }

    check_post() {
      local name="$1" url="$2"
      printf "  %-30s " "$name"
      local http_code
      http_code=$(${pkgs.curl}/bin/curl -s -o /dev/null -w "%{http_code}" \
        --max-time 5 --connect-timeout 3 \
        -X POST -H "Content-Type: application/json" \
        -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"health-check","version":"1.0"}}}' \
        "$url" 2>/dev/null || echo "000")
      if [[ "$http_code" == "000" ]]; then
        echo "✗  UNREACHABLE (connection refused or timeout)"
        fail=$((fail + 1))
      elif [[ "$http_code" -ge 200 && "$http_code" -lt 500 ]]; then
        echo "✓  OK (HTTP $http_code)"
        ok=$((ok + 1))
      else
        echo "✗  ERROR (HTTP $http_code)"
        fail=$((fail + 1))
      fi
    }

    echo "Cline MCP server health check"
    echo "─────────────────────────────────────────────"
    ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: srv:
      if srv.type == "streamableHttp"
      then "check_post ${lib.escapeShellArg name} ${lib.escapeShellArg srv.url}"
      else "check_get  ${lib.escapeShellArg name} ${lib.escapeShellArg srv.url}"
    ) cfg.mcp.servers)}
    echo "─────────────────────────────────────────────"
    echo "  $ok OK  /  $fail failed"
    [[ $fail -eq 0 ]]
  '';

in
{
  options.my.programs.cline = {
    enable = mkEnableOption "Cline – AI coding agent in VS Code and terminal";

    # ── Ollama integration ─────────────────────────────────────────────────

    ollamaModels = mkOption {
      type    = types.attrsOf types.anything;
      default = {};
      example = literalExpression ''
        {
          "gemma4:e4b"        = { cline_default = true; };
          "qwen2.5-coder:14b" = {};
        }
      '';
      description = ''
        Ollama models available to Cline.
        Set <literal>cline_default = true</literal> on exactly one model to
        use it as the active model; otherwise <option>model</option> is used.
      '';
    };

    ollamaBaseURL = mkOption {
      type    = types.str;
      default = "http://127.0.0.1:11434";
      example = "http://my-gpu-box:11434";
      description = ''
        Base URL for the Ollama server — no trailing slash, no
        <literal>/v1</literal> suffix.  The ollama provider adds the path
        itself.  Exported as <envar>OLLAMA_HOST</envar>.
      '';
    };

    model = mkOption {
      type    = types.str;
      default = "";
      example = "gemma4:e4b";
      description = ''
        Fallback model tag when no entry in <option>ollamaModels</option> has
        <literal>cline_default = true</literal>.
      '';
    };

    # ── MCP server declarations ────────────────────────────────────────────

    mcp = {
      servers = mkOption {
        type = types.attrsOf (types.submodule {
          options = {
            type = mkOption {
              type    = types.enum [ "sse" "streamableHttp" "stdio" ];
              default = "sse";
              description = ''
                MCP transport type.
                <literal>sse</literal> — for local servers wrapped by
                supergateway; endpoint ends in <literal>/sse</literal>.
                <literal>streamableHttp</literal> — for hosted services
                (Linear, etc.); endpoint ends in <literal>/mcp</literal>.
                <literal>stdio</literal> — local process, no URL needed.
              '';
            };

            url = mkOption {
              type    = types.str;
              default = "";
              example = "http://my-server:3100/sse";
              description = "URL the MCP client connects to.";
            };

            env = mkOption {
              type    = types.attrsOf types.str;
              default = {};
              description = "Environment variables for stdio servers.";
            };

            headers = mkOption {
              type    = types.attrsOf types.str;
              default = {};
              description = "HTTP headers for sse/streamableHttp servers.";
            };
          };
        });
        default = {};
        example = literalExpression ''
          {
            # Local Ollama MCP via supergateway — must use sse + /sse
            ollama = {
              type = "sse";
              url  = "http://100.119.248.77:3100/sse";
            };
            # Hosted Linear MCP — streamableHttp
            linear = {
              type = "streamableHttp";
              url  = "https://mcp.linear.app/mcp";
            };
          }
        '';
        description = ''
          Declarative MCP server definitions written to
          <filename>~/.cline/data/settings/cline_mcp_settings.json</filename>
          on every <command>home-manager switch</command>.
          Nix is always authoritative for the server list.
        '';
      };
    };

    # ── VS Code settings pass-through ──────────────────────────────────────

    settings = mkOption {
      type    = types.attrsOf types.anything;
      default = {};
      example = literalExpression ''
        {
          "cline.maxTokens"               = 16384;
          "cline.terminalOutputLineLimit" = 500;
        }
      '';
      description = ''
        Extra VS Code settings merged into the Cline fragment.
        Keys must be fully-qualified (i.e. <literal>"cline.*"</literal>).
        Values here take precedence over all shorthand options above.
      '';
    };

    vsCodeSettingsPath = mkOption {
      type    = types.str;
      default = ".config/Code/User/settings.json";
      example = ".config/VSCodium/User/settings.json";
      description = "Path relative to HOME for VS Code settings.json.";
    };

    # ── Kanban CLI ─────────────────────────────────────────────────────────

    kanban = {
      enable = mkOption {
        type    = types.bool;
        default = false;
        description = ''
          Install the <command>cline-kanban</command> CLI — a browser-based
          kanban board for orchestrating multiple Cline agents in parallel
          via git worktrees.
        '';
      };

      extraArgs = mkOption {
        type    = types.listOf types.str;
        default = [];
        example = literalExpression ''[ "--host" "0.0.0.0" "--port" "3484" ]'';
        description = "Extra flags passed to kanban on every invocation.";
      };
    };
  };

  # ── Implementation ─────────────────────────────────────────────────────────
  config = mkIf cfg.enable {

    assertions = [
      {
        assertion =
          let
            defaults = lib.filter
              (tag: cfg.ollamaModels.${tag}.cline_default or false)
              (lib.attrNames cfg.ollamaModels);
          in
          builtins.length defaults <= 1;
        message = ''
          my.programs.cline.ollamaModels: at most one model may have
          `cline_default = true`.
        '';
      }
      {
        assertion = usingOllama -> clineDefaultModel != "";
        message = ''
          my.programs.cline: ollamaModels is non-empty but no default model
          could be determined.  Either set `cline_default = true` on one
          model or set `my.programs.cline.model`.
        '';
      }
    ];

    # ── Provider config ────────────────────────────────────────────────────

    home.activation.writeClineProviders = lib.mkIf usingOllama (
      lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        mkdir -p $HOME/.cline/data/settings
        $DRY_RUN_CMD rm -f $HOME/.cline/data/settings/providers.json
        $DRY_RUN_CMD cp ${clineProvidersFile} \
          $HOME/.cline/data/settings/providers.json
        $DRY_RUN_CMD chmod 644 \
          $HOME/.cline/data/settings/providers.json
      ''
    );

    # ── MCP settings ───────────────────────────────────────────────────────

    home.activation.writeClineMcpSettings = lib.mkIf hasMcpServers (
      lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        mkdir -p $HOME/.cline/data/settings

        $DRY_RUN_CMD rm -f $HOME/.cline/data/settings/cline_mcp_settings.json
        $DRY_RUN_CMD cp ${clineMcpSettingsFile} \
          $HOME/.cline/data/settings/cline_mcp_settings.json
        $DRY_RUN_CMD chmod 644 \
          $HOME/.cline/data/settings/cline_mcp_settings.json

        if [[ ! -f $HOME/.cline/data/settings/cline_mcp_oauth_settings.json ]]; then
          $DRY_RUN_CMD cp ${clineMcpOAuthSettingsFile} \
            $HOME/.cline/data/settings/cline_mcp_oauth_settings.json
          $DRY_RUN_CMD chmod 644 \
            $HOME/.cline/data/settings/cline_mcp_oauth_settings.json
        fi
      ''
    );

    # ── Packages ───────────────────────────────────────────────────────────

    home.packages =
      lib.optional cfg.kanban.enable (
        pkgs.writeShellScriptBin "cline-kanban" ''
          export NPM_CONFIG_PREFIX=$HOME/.npm-global
          export PATH=${nodejs}/bin:$HOME/.npm-global/bin:$PATH
          exec ${lib.getExe nodejs} $HOME/.npm-global/bin/kanban \
            ${lib.escapeShellArgs cfg.kanban.extraArgs} \
            "$@"
        ''
      )
      ++ lib.optional hasMcpServers mcpHealthScript;

    home.activation.installKanban = lib.mkIf cfg.kanban.enable (
      lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        export NPM_CONFIG_PREFIX=$HOME/.npm-global
        export PATH=${lib.makeBinPath [
          nodejs
          pkgs.python3
          pkgs.gcc
          pkgs.gnumake
          pkgs.gnutar
          pkgs.gzip
        ]}:$PATH
        $DRY_RUN_CMD ${nodejs}/bin/npm install -g kanban cline
      ''
    );

    # ── VS Code settings ───────────────────────────────────────────────────

    programs.vscode.userSettings = mkIf
      (config.programs.vscode.enable or false)
      clineVSCodeSettings;

    home.file."${cfg.vsCodeSettingsPath}" = mkIf
      (!(config.programs.vscode.enable or false))
      {
        text  = builtins.toJSON clineVSCodeSettings;
        force = false;
      };

    # ── Environment ────────────────────────────────────────────────────────

    home.sessionVariables =
      optionalAttrs usingOllama {
        OLLAMA_HOST = cfg.ollamaBaseURL;
      }
      // optionalAttrs cfg.kanban.enable {
        NPM_CONFIG_PREFIX = "$HOME/.npm-global";
        PATH              = "$HOME/.npm-global/bin:$PATH";
      };
  };
}
