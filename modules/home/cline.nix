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
              type    = types.s