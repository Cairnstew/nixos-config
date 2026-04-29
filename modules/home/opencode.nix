# modules/my/programs/opencode.nix
{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib)
    mkEnableOption
    mkIf
    mkMerge
    mkOption
    types
    ;

  cfg = config.my.programs.opencode;

  # Convert an ollama model attrset entry into an opencode provider model entry.
  # Strips ollama-specific fields (tools, numCtx, etc.) that opencode doesn't understand.
  # The model name in opencode is always "ollama/<tag>".
  ollamaModelToProvider = tag: _mcfg: {
    name     = "ollama/${tag}";
    provider = "ollama";
  };

  defaultModel = lib.findFirst
    (tag: (cfg.ollamaModels.${tag}.opencode_default or false) == true)
    null
    (lib.attrNames cfg.ollamaModels);

  # Build the providers block if any ollamaModels were supplied.
  ollamaProviderSettings = lib.optionalAttrs (cfg.ollamaModels != {}) {
    provider.ollama = {        # <-- singular, not providers
      npm             = "@ai-sdk/openai-compatible";
      name            = "Ollama (local)";
      options.baseURL = cfg.ollamaBaseURL;
      models = lib.mapAttrs (tag: mcfg:
        let
          modelOpts = lib.filterAttrs (_: v: v != null) {
            num_ctx        = mcfg.numCtx        or null;
            temperature    = mcfg.temperature   or null;
            top_p          = mcfg.topP          or null;
            top_k          = mcfg.topK          or null;
            repeat_penalty = mcfg.repeatPenalty or null;
            num_predict    = mcfg.numPredict    or null;
            seed           = mcfg.seed          or null;
          };
        in
        { name = mcfg.name or tag; tools = mcfg.tools or false; }
        // lib.optionalAttrs (modelOpts != {}) { options = modelOpts; }
      ) cfg.ollamaModels;
    };
  };

in
{
  options.my.programs.opencode = {

    enable = mkEnableOption "opencode – AI coding agent for the terminal";

    package = mkOption {
      type        = types.nullOr types.package;
      default     = pkgs.opencode;
      defaultText = lib.literalExpression "pkgs.opencode";
      description = "The opencode package to use.";
    };

    enableMcpIntegration = mkOption {
      type        = types.bool;
      default     = false;
      description = "Forward programs.mcp.servers into opencode's MCP configuration.";
    };

    # ── Ollama integration ────────────────────────────────────────────────

    ollamaModels = mkOption {
      # Accepts the same attrset shape as my.services.ollama.models —
      # extra fields (tools, numCtx, temperature, etc.) are silently ignored.
      type    = types.attrsOf types.anything;
      default = {};
      example = {
        "qwen3.5:9b" = {
          name        = "qwen3.5:9b";
          tools       = true;
          numCtx      = 32768;
          temperature = 0.7;
        };
      };
      description = ''
        Ollama models to expose to opencode. Accepts the same attrset shape as
        my.services.ollama.models — ollama-specific fields are ignored.
        Each key becomes an "ollama/<tag>" model entry in opencode's provider config.
      '';
    };

    ollamaBaseURL = mkOption {
      type        = types.str;
      default     = "http://127.0.0.1:11434/v1";
      example     = "http://100.64.0.1:11434/v1";
      description = "Base URL for the Ollama API (OpenAI-compatible endpoint).";
    };

    # ── Shorthand options ─────────────────────────────────────────────────

    model = mkOption {
      type        = types.nullOr types.str;
      default     = null;
      example     = "anthropic/claude-sonnet-4-20250514";
      description = "Shorthand for settings.model.";
    };

    autoshare = mkOption {
      type        = types.nullOr types.bool;
      default     = null;
      description = "Shorthand for settings.autoshare.";
    };

    autoupdate = mkOption {
      type        = types.nullOr types.bool;
      default     = null;
      description = "Shorthand for settings.autoupdate.";
    };

    # ── Pass-throughs ─────────────────────────────────────────────────────

    settings = mkOption {
      type        = (pkgs.formats.json {}).type;
      default     = {};
      description = "Verbatim JSON config written to $XDG_CONFIG_HOME/opencode/config.json.";
    };

    rules = mkOption {
      type        = types.either types.lines types.path;
      default     = "";
      description = "Global custom instructions written to $XDG_CONFIG_HOME/opencode/AGENTS.md.";
    };

    commands = mkOption {
      type    = types.attrsOf (types.either types.lines types.path);
      default = {};
      description = "Custom slash-commands.";
    };

    agents = mkOption {
      type    = types.attrsOf (types.either types.lines types.path);
      default = {};
      description = "Custom agents.";
    };

    themes = mkOption {
      type    = types.attrsOf (types.either (pkgs.formats.json {}).type types.path);
      default = {};
      description = "Custom colour themes.";
    };
  };

  # ── Implementation ────────────────────────────────────────────────────────

  config = mkIf cfg.enable {
    programs.opencode = mkMerge [
      {
        enable               = true;
        package              = cfg.package;
        enableMcpIntegration = cfg.enableMcpIntegration;
        rules                = cfg.rules;
        commands             = cfg.commands;
        agents               = cfg.agents;
        themes               = cfg.themes;
        settings             = cfg.settings;
      }

      # Merge ollama provider block if any models were declared
      (mkIf (cfg.ollamaModels != {}) {
        settings = ollamaProviderSettings;
      })

      # Auto-set default model if opencode_default = true on any model
      (mkIf (defaultModel != null) {
        settings.model = "ollama/${defaultModel}";
      })

      (mkIf (cfg.model      != null) { settings.model      = cfg.model; })
      (mkIf (cfg.autoshare  != null) { settings.autoshare  = cfg.autoshare; })
      (mkIf (cfg.autoupdate != null) { settings.autoupdate = cfg.autoupdate; })
    ];
  };
}