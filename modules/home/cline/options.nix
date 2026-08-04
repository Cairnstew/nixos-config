# modules/home/cline/options.nix
{ lib, ... }:

let
  inherit (lib)
    literalExpression
    mkEnableOption
    mkOption
    types
    ;
in
{
  options.my.programs.cline = {
    enable = mkEnableOption "Cline – AI coding agent in VS Code and terminal";

    # ── Ollama integration ─────────────────────────────────────────────────

    ollamaModels = mkOption {
      type = types.attrsOf types.anything;
      default = { };
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
      type = types.str;
      default = "http://127.0.0.1:11434";
      example = "http://my-gpu-box:11434";
      description = ''
        Base URL for the Ollama server — no trailing slash, no
        <literal>/v1</literal> suffix.  The ollama provider adds the path
        itself.  Exported as <envar>OLLAMA_HOST</envar>.
      '';
    };

    model = mkOption {
      type = types.str;
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
              type = types.enum [ "sse" "streamableHttp" "stdio" ];
              default = "streamableHttp";
              description = ''
                MCP transport type.
                <literal>streamableHttp</literal> — modern stateless transport;
                endpoint ends in <literal>/mcp</literal>.  Use this for
                supergateway and hosted services (Linear, etc.).
                <literal>sse</literal> — legacy single-client transport;
                endpoint ends in <literal>/sse</literal>.  Only for servers
                that don't support streamableHttp.
                <literal>stdio</literal> — local process, no URL needed.
              '';
            };

            url = mkOption {
              type = types.str;
              default = "";
              example = "http://my-server:3100/mcp";
              description = ''
                URL the MCP client connects to.
                streamableHttp servers: end in <literal>/mcp</literal>.
                SSE servers: end in <literal>/sse</literal>.
              '';
            };

            env = mkOption {
              type = types.attrsOf types.str;
              default = { };
              description = "Environment variables for stdio servers.";
            };

            headers = mkOption {
              type = types.attrsOf types.str;
              default = { };
              description = "HTTP headers for sse/streamableHttp servers.";
            };
          };
        });
        default = { };
        example = literalExpression ''
          {
            # Local Ollama MCP via supergateway — streamableHttp at /mcp
            ollama = {
              type = "streamableHttp";
              url  = "http://100.78.102.28:3100/mcp";
            };
            # Hosted Linear MCP
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
      type = types.attrsOf types.anything;
      default = { };
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
      type = types.str;
      default = ".config/Code/User/settings.json";
      example = ".config/VSCodium/User/settings.json";
      description = "Path relative to HOME for VS Code settings.json.";
    };

    # ── Kanban CLI ─────────────────────────────────────────────────────────

    kanban = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Install the <command>cline-kanban</command> CLI — a browser-based
          kanban board for orchestrating multiple Cline agents in parallel
          via git worktrees.
        '';
      };

      extraArgs = mkOption {
        type = types.listOf types.str;
        default = [ ];
        example = literalExpression ''[ "--host" "0.0.0.0" "--port" "3484" ]'';
        description = "Extra flags passed to kanban on every invocation.";
      };
    };
  };
}
