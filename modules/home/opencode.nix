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

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  # Build a provider.ollama block from the ollamaModels attrset.
  # Strips Ollama-specific fields that opencode doesn't understand.
  ollamaProviderSettings = lib.optionalAttrs (cfg.ollamaModels != {}) {
    provider.ollama = {
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

  # Find the first Ollama model tagged opencode_default = true, if any.
  defaultOllamaModel = lib.findFirst
    (tag: (cfg.ollamaModels.${tag}.opencode_default or false) == true)
    null
    (lib.attrNames cfg.ollamaModels);

  # Build a provider.groq block when a key file path is supplied.
  groqProviderSettings = lib.optionalAttrs (cfg.groq.keyFile != null) {
    provider.groq = {
      npm  = "@ai-sdk/groq";
      name = "Groq";
      # opencode reads the env var GROQ_API_KEY at runtime; we arrange for the
      # shell to export it from the key file via home.sessionVariables below.
    };
  };

  # Build a provider.clarifai block when a PAT file path is supplied.
  # Clarifai exposes an OpenAI-compatible endpoint so we use the openai-compatible
  # npm package.  Model IDs are short slugs as returned by the /models endpoint, e.g.:
  #   gpt-oss-120b, gpt-oss-20b, DeepSeek-R1, Kimi-K2_6
  # Use {file:...} substitution because opencode has a known bug where
  # {env:...} does not expand for apiKey in openai-compatible providers.
  clarifaiProviderSettings = lib.optionalAttrs (cfg.clarifai.patFile != null) {
    provider.clarifai = {
      npm             = "@ai-sdk/openai-compatible";
      name            = "Clarifai";
      options.baseURL = "https://api.clarifai.com/v2/ext/openai/v1";
      options.apiKey  = "{file:${cfg.clarifai.patFile}}";
    };
  };

in
{
  # ---------------------------------------------------------------------------
  # Options
  # ---------------------------------------------------------------------------

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

    # ── Groq ────────────────────────────────────────────────────────────────

    groq = {
      keyFile = mkOption {
        type        = types.nullOr types.path;
        default     = null;
        example     = "/run/secrets/groq-api-key";
        description = ''
          Path to a file containing the Groq API key.
          When set, GROQ_API_KEY is exported in your shell session from this
          file and the Groq provider is registered in opencode's config.

          Recommended models to set with <option>my.programs.opencode.model</option>:
            - groq/llama-3.3-70b-versatile   (best quality, ~$0.59/$0.79 per M tokens)
            - groq/llama-3.1-8b-instant       (fastest, ~$0.05/$0.08 per M tokens)
            - groq/llama-4-scout              (good middle ground)
        '';
      };
    };

    # ── Clarifai ─────────────────────────────────────────────────────────────

    clarifai = {
      patFile = mkOption {
        type        = types.nullOr types.path;
        default     = null;
        example     = "/run/secrets/clarifai-pat";
        description = ''
          Path to a file containing a Clarifai Personal Access Token (PAT).
          When set, the Clarifai provider is registered in opencode's config
          and the PAT is read directly from the file at runtime via opencode's
          {file:...} substitution.

          Get a PAT from the Secrets section of your Clarifai app settings.

          Model IDs are short slugs — check available models with:
            curl -s https://api.clarifai.com/v2/ext/openai/v1/models \
              -H "Authorization: Key $(cat /path/to/pat)" | jq '.[].id'

          Set with <option>my.programs.opencode.model</option> using the
          "clarifai/" prefix, e.g.:
            - clarifai/gpt-oss-120b
            - clarifai/gpt-oss-20b
            - clarifai/DeepSeek-R1
            - clarifai/Kimi-K2_6
        '';
      };
    };

    # ── Ollama ──────────────────────────────────────────────────────────────

    ollamaModels = mkOption {
      type    = types.attrsOf types.anything;
      default = {};
      example = {
        "qwen3.5:9b" = {
          name        = "qwen3.5:9b";
          tools       = true;
          numCtx      = 32768;
          temperature = 0.7;
          opencode_default = true;
        };
      };
      description = ''
        Ollama models to expose to opencode.  Accepts the same attrset shape as
        <option>my.services.ollama.models</option>; Ollama-specific fields are
        silently ignored by opencode.

        Set <literal>opencode_default = true</literal> on exactly one model to
        make it the default.  Each key becomes an
        <literal>ollama/&lt;tag&gt;</literal> entry in the provider config.
      '';
    };

    ollamaBaseURL = mkOption {
      type        = types.str;
      default     = "http://127.0.0.1:11434/v1";
      example     = "http://100.64.0.1:11434/v1";
      description = "Base URL for the Ollama OpenAI-compatible endpoint.";
    };

    # ── Shorthands ───────────────────────────────────────────────────────────

    model = mkOption {
      type        = types.nullOr types.str;
      default     = null;
      example     = "groq/llama-3.3-70b-versatile";
      description = "Shorthand for <option>settings.model</option>.";
    };

    autoshare = mkOption {
      type        = types.nullOr types.bool;
      default     = null;
      description = "Shorthand for <option>settings.autoshare</option>.";
    };

    autoupdate = mkOption {
      type        = types.nullOr types.bool;
      default     = null;
      description = "Shorthand for <option>settings.autoupdate</option>.";
    };

    # ── Pass-throughs ────────────────────────────────────────────────────────

    settings = mkOption {
      type        = (pkgs.formats.json {}).type;
      default     = {};
      description = "Verbatim JSON written to \$XDG_CONFIG_HOME/opencode/config.json.";
    };

    rules = mkOption {
      type        = types.either types.lines types.path;
      default     = "";
      description = "Global instructions written to \$XDG_CONFIG_HOME/opencode/AGENTS.md.";
    };

    commands = mkOption {
      type        = types.attrsOf (types.either types.lines types.path);
      default     = {};
      description = "Custom slash-commands.";
    };

    agents = mkOption {
      type        = types.attrsOf (types.either types.lines types.path);
      default     = {};
      description = "Custom agents.";
    };

    themes = mkOption {
      type        = types.attrsOf (types.either (pkgs.formats.json {}).type types.path);
      default     = {};
      description = "Custom colour themes.";
    };
  };

  # ---------------------------------------------------------------------------
  # Implementation
  # ---------------------------------------------------------------------------

  config = mkIf cfg.enable (mkMerge [

    # Base opencode config
    {
      programs.opencode = {
        enable               = true;
        package              = cfg.package;
        enableMcpIntegration = cfg.enableMcpIntegration;
        rules                = cfg.rules;
        commands             = cfg.commands;
        agents               = cfg.agents;
        themes               = cfg.themes;
        settings             = cfg.settings;
      };
    }

    # Groq: export API key from file and register the provider
    (mkIf (cfg.groq.keyFile != null) {
      home.sessionVariables.GROQ_API_KEY = "$(cat ${cfg.groq.keyFile})";
      programs.opencode.settings = groqProviderSettings;
    })

    # Clarifai: register provider using {file:...} substitution for the PAT.
    # Note: {env:...} has a known opencode bug for openai-compatible apiKey fields.
    (mkIf (cfg.clarifai.patFile != null) {
      programs.opencode.settings = clarifaiProviderSettings;
    })

    # Ollama: register provider if any models are declared
    (mkIf (cfg.ollamaModels != {}) {
      programs.opencode.settings = ollamaProviderSettings;
    })

    # Ollama: auto-select default model if one is tagged
    (mkIf (defaultOllamaModel != null) {
      programs.opencode.settings.model = "ollama/${defaultOllamaModel}";
    })

    # Shorthands (highest priority — override any auto-set model above)
    (mkIf (cfg.model      != null) { programs.opencode.settings.model      = cfg.model; })
    (mkIf (cfg.autoshare  != null) { programs.opencode.settings.autoshare  = cfg.autoshare; })
    (mkIf (cfg.autoupdate != null) { programs.opencode.settings.autoupdate = cfg.autoupdate; })

  ]);
}
