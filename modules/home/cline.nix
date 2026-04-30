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

  # VS Code settings fragment that the Cline extension reads.
  clineVSCodeSettings =
    {
      "cline.apiProvider"   = "ollama";
      "cline.ollamaBaseUrl" = cfg.ollamaBaseURL;
      "cline.ollamaModelId" = clineDefaultModel;
    }
    // cfg.settings;

  # providers.json written as a Nix store text file so we can copy (not
  # symlink) it into ~/.cline/data/settings/ — Cline writes back to this
  # file at runtime so it must be mutable.
  clineProvidersFile = pkgs.writeText "cline-providers.json" (
    builtins.toJSON {
      version          = 1;
      lastUsedProvider = "ollama";
      providers = {
        ollama = {
          settings = {
            provider = "ollama";
            model    = clineDefaultModel;
            baseUrl  = "${cfg.ollamaBaseURL}/v1";
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
  # ---------------------------------------------------------------------------

  mcpServersObj = lib.mapAttrs (_name: srv:
    { inherit (srv) type url; }
    // lib.optionalAttrs (srv.env     != {}) { inherit (srv) env; }
    // lib.optionalAttrs (srv.headers != {}) { inherit (srv) headers; }
  ) cfg.mcp.servers;

  clineMcpSettingsFile = pkgs.writeText "cline-mcp-settings.json" (
    builtins.toJSON { mcpServers = mcpServersObj; }
  );

  clineMcpOAuthSettingsFile = pkgs.writeText "cline-mcp-oauth-settings.json" (
    builtins.toJSON {
      servers = lib.mapAttrs (_name: _srv: {}) cfg.mcp.servers;
    }
  );

  hasMcpServers = cfg.mcp.servers != {};

  # ---------------------------------------------------------------------------
  # Health-check script for all configured MCP servers.
  # streamableHttp needs a POST; SSE needs a GET — we detect by type.
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
          "qwen2.5-coder:14b" = { cline_default = true; };
          "codestral:22b"     = {};
          "mistral:7b"        = {};
        }
      '';
      description = ''
        Ollama models to expose to Cline.
        Set <literal>cline_default = true</literal> on exactly one model to use
        it as the active model; otherwise <option>model</option> is used.
      '';
    };

    ollamaBaseURL = mkOption {
      type    = types.str;
      default = "http://127.0.0.1:11434";
      example = "http://my-gpu-box:11434";
      description = ''
        Base URL for the Ollama server, without a trailing slash and without
        the <literal>/v1</literal> suffix — the module appends that
        automatically for the Cline CLI provider config.  Exported as
        <envar>OLLAMA_HOST</envar>.
      '';
    };

    # ── Shorthand options ──────────────────────────────────────────────────

    model = mkOption {
      type    = types.str;
      default = "";
      example = "qwen2.5-coder:14b";
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
              # streamableHttp is the modern, multi-client-safe transport.
              # Use "sse" only for older servers that don't support it.
              default = "streamableHttp";
              description = ''
                MCP transport type.
                <literal>streamableHttp</literal> — modern, stateless, supports
                multiple simultaneous clients; endpoint typically ends in
                <literal>/mcp</literal>.  Preferred for all new servers.
                <literal>sse</literal> — legacy transport; single client only;
                endpoint typically ends in <literal>/sse</literal>.
                <literal>stdio</literal> — local process; no URL needed.
              '';
            };

            url = mkOption {
              type    = types.str;
              default = "";
              example = "http://my-server:3100/mcp";
              description = ''
                URL the MCP client connects to.
                For <literal>streamableHttp</literal>: typically ends in
                <literal>/mcp</literal>.
                For <literal>sse</literal>: typically ends in
                <literal>/sse</literal>.
                Not used for <literal>stdio</literal> servers.
              '';
            };

            env = mkOption {
              type    = types.attrsOf types.str;
              default = {};
              example = literalExpression ''{ API_KEY = "secret"; }'';
              description = "Environment variables passed to the MCP server process (stdio only).";
            };

            headers = mkOption {
              type    = types.attrsOf types.str;
              default = {};
              example = literalExpression ''{ Authorization = "Bearer token"; }'';
              description = "HTTP headers sent with every request (sse / streamableHttp).";
            };
          };
        });
        default = {};
        example = literalExpression ''
          {
            # Local Ollama MCP server — uses streamableHttp (multi-client safe)
            ollama = {
              type = "streamableHttp";
              url  = "http://my-server:3100/mcp";
            };
            # Hosted Linear MCP
            linear = {
              type = "streamableHttp";
              url  = "https://mcp.linear.app/mcp";
            };
            # Legacy SSE server
            legacy = {
              type = "sse";
              url  = "http://my-server:3200/sse";
            };
          }
        '';
        description = ''
          Declarative MCP server definitions written to
          <filename>~/.cline/data/settings/cline_mcp_settings.json</filename>
          on every <command>home-manager switch</command>.

          The file is copied (not symlinked) so Cline can still update it at
          runtime.  The Nix declaration is always authoritative for the server
          list; transient runtime edits will be overwritten on next switch.
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
        Extra key/value pairs merged into the Cline VS Code settings fragment.
        Keys must be fully-qualified VS Code setting names
        (i.e. <literal>"cline.*"</literal>).  Values here take precedence over
        all shorthand options above.
      '';
    };

    vsCodeSettingsPath = mkOption {
      type    = types.str;
      default = ".config/Code/User/settings.json";
      example = ".config/VSCodium/User/settings.json";
      description = ''
        Path relative to <envar>HOME</envar> for the VS Code
        <filename>settings.json</filename> file.  Override for VS Code OSS,
        VSCodium, or a non-standard XDG base directory.
      '';
    };

    # ── Kanban CLI ─────────────────────────────────────────────────────────

    kanban = {
      enable = mkOption {
        type    = types.bool;
        default = false;
        description = ''
          Install the <command>cline-kanban</command> CLI — a browser-based
          kanban board for orchestrating multiple coding agents in parallel
          via git worktrees.  Run <command>cline-kanban</command> from the
          root of any git repo to open the board in your browser.

          Also installs the <command>cline</command> CLI agent into
          <filename>~/.npm-global/bin</filename> so Kanban can detect and
          launch it automatically.

          Use <literal>--host 0.0.0.0</literal> in <option>extraArgs</option>
          when running on a remote machine or WSL so the board is reachable
          from your browser at <literal>http://&lt;host-ip&gt;:3484</literal>.
        '';
      };

      extraArgs = mkOption {
        type    = types.listOf types.str;
        default = [];
        example = literalExpression ''[ "--host" "0.0.0.0" "--port" "3484" ]'';
        description = ''
          Extra command-line flags passed to <command>kanban</command> on
          every invocation.
        '';
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

    # ── Cline CLI provider config ──────────────────────────────────────────

    home.activation.writeClineProviders = lib.mkIf usingOllama (
      lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        mkdir -p $HOME/.cline/data/settings
        $DRY_RUN_CMD cp -f ${clineProvidersFile} \
          $HOME/.cline/data/settings/providers.json
        $DRY_RUN_CMD chmod 644 \
          $HOME/.cline/data/settings/providers.json
      ''
    );

    # ── MCP settings files ─────────────────────────────────────────────────

    home.activation.writeClineMcpSettings = lib.mkIf hasMcpServers (
      lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        mkdir -p $HOME/.cline/data/settings

        # Server list — always overwrite so Nix is authoritative.
        $DRY_RUN_CMD cp -f ${clineMcpSettingsFile} \
          $HOME/.cline/data/settings/cline_mcp_settings.json
        $DRY_RUN_CMD chmod 644 \
          $HOME/.cline/data/settings/cline_mcp_settings.json

        # OAuth state — seed only; never overwrite Cline's runtime tokens.
        if [[ ! -f $HOME/.cline/data/settings/cline_mcp_oauth_settings.json ]]; then
          $DRY_RUN_CMD cp ${clineMcpOAuthSettingsFile} \
            $HOME/.cline/data/settings/cline_mcp_oauth_settings.json
          $DRY_RUN_CMD chmod 644 \
            $HOME/.cline/data/settings/cline_mcp_oauth_settings.json
        fi
      ''
    );

    # ── Kanban + Cline CLI + health-check packages ─────────────────────────

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