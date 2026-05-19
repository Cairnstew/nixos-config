{ config, lib, pkgs, ... }:

let
  inherit (lib)
    mkEnableOption
    mkOption
    types
    literalExpression
    ;

  # Common keyFile option for SDK-based providers
  mkKeyFileOpt = description: mkOption {
    type        = types.nullOr types.path;
    default     = null;
    example     = "/run/secrets/api-key";
    inherit description;
  };

  # Common keyFile option for OpenAI-compatible providers
  mkOpenAiKeyFileOpt = description: mkOption {
    type        = types.nullOr types.path;
    default     = null;
    example     = "/run/secrets/api-key";
    description = description + ''

      Uses {file:...} substitution because opencode has a known bug where
      {env:...} does not expand for apiKey in openai-compatible providers.
    '';
  };

in {
  options.my.programs.opencode = {

    enable = mkEnableOption "opencode – AI coding agent for the terminal";

    package = mkOption {
      type        = types.nullOr types.package;
      default     = pkgs.opencode;
      defaultText = literalExpression "pkgs.opencode";
      description = "The opencode package to use.";
    };

    enableMcpIntegration = mkOption {
      type        = types.bool;
      default     = false;
      description = "Forward programs.mcp.servers into opencode's MCP configuration.";
    };

    # ── SDK-based cloud providers (env-var keys) ────────────────────────────

    openai = {
      keyFile = mkKeyFileOpt ''
        Path to a file containing the OpenAI API key.
        When set, OPENAI_API_KEY is exported in your shell session and the
        OpenAI provider is registered.

        Recommended models:
          - openai/gpt-4o
          - openai/gpt-4o-mini
          - openai/o3-mini
      '';
    };

    anthropic = {
      keyFile = mkKeyFileOpt ''
        Path to a file containing the Anthropic API key.
        When set, ANTHROPIC_API_KEY is exported and the Anthropic provider is
        registered.

        Recommended models:
          - anthropic/claude-sonnet-4-20250514
          - anthropic/claude-opus-4-20250514
          - anthropic/claude-3-5-haiku-20241022
      '';
    };

    google = {
      keyFile = mkKeyFileOpt ''
        Path to a file containing the Google Generative AI API key.
        When set, GOOGLE_GENERATIVE_AI_API_KEY is exported and the Google
        provider is registered.

        Recommended models:
          - google/gemini-2.5-pro
          - google/gemini-2.5-flash
          - google/gemini-2.0-flash
      '';
    };

    groq = {
      keyFile = mkKeyFileOpt ''
        Path to a file containing the Groq API key.
        When set, GROQ_API_KEY is exported and the Groq provider is registered.

        Recommended models:
          - groq/llama-3.3-70b-versatile
          - groq/llama-3.1-8b-instant
          - groq/llama-4-scout
      '';
    };

    mistral = {
      keyFile = mkKeyFileOpt ''
        Path to a file containing the Mistral API key.
        When set, MISTRAL_API_KEY is exported and the Mistral provider is
        registered.

        Recommended models:
          - mistral/mistral-large-latest
          - mistral/mistral-small-latest
          - mistral/codestral-latest
      '';
    };

    xai = {
      keyFile = mkKeyFileOpt ''
        Path to a file containing the xAI API key.
        When set, XAI_API_KEY is exported and the xAI provider is registered.

        Recommended models:
          - xai/grok-3-beta
          - xai/grok-3-mini-beta
      '';
    };

    deepinfra = {
      keyFile = mkKeyFileOpt ''
        Path to a file containing the DeepInfra API key.
        When set, DEEPINFRA_API_KEY is exported.

        Note: This only exports the API key. You must manually configure the
        provider in your opencode.json or use the `/connect` command in opencode.

        Recommended models:
          - deepinfra/deepseek-ai/DeepSeek-V3-0324
          - deepinfra/deepseek-ai/DeepSeek-R1
          - deepinfra/moonshotai/Kimi-K2.5
      '';
    };

    # ── OpenAI-compatible providers (file-substitution keys) ────────────────

    together = {
      keyFile = mkOpenAiKeyFileOpt ''
        Path to a file containing a Together AI API key.
        When set, the Together provider is registered.

        Get a key at https://api.together.xyz/settings/api-keys.

        Recommended models:
          - together/deepseek-ai/DeepSeek-V3
          - together/meta-llama/Llama-3.3-70B-Instruct-Turbo
          - together/Qwen/Qwen2.5-72B-Instruct-Turbo
      '';
    };

    openrouter = {
      keyFile = mkOpenAiKeyFileOpt ''
        Path to a file containing an OpenRouter API key.
        When set, the OpenRouter provider is registered.

        Get a key at https://openrouter.ai/settings/keys.

        Recommended models:
          - openrouter/anthropic/claude-sonnet-4
          - openrouter/openai/gpt-4o
          - openrouter/google/gemini-2.5-pro
      '';
    };

    fireworks = {
      keyFile = mkOpenAiKeyFileOpt ''
        Path to a file containing a Fireworks AI API key.
        When set, the Fireworks provider is registered.

        Get a key at https://fireworks.ai/account/api-keys.

        Recommended models:
          - fireworks/accounts/fireworks/models/llama4-maverick-instruct-basic
          - fireworks/accounts/fireworks/models/deepseek-v3-0324
      '';
    };

    cerebras = {
      keyFile = mkOpenAiKeyFileOpt ''
        Path to a file containing a Cerebras API key.
        When set, the Cerebras provider is registered.

        Get a key at https://cloud.cerebras.ai/platform/org_level/api_keys.

        Recommended models:
          - cerebras/llama-4-scout-17b-16e-instruct
          - cerebras/llama-4-maverick-17b-128e-instruct
      '';
    };

    clarifai = {
      patFile = mkOpenAiKeyFileOpt ''
        Path to a file containing a Clarifai Personal Access Token (PAT).
        When set, the Clarifai provider is registered.

        Get a PAT from the Secrets section of your Clarifai app settings.

        Recommended models:
          - clarifai/gpt-oss-120b
          - clarifai/DeepSeek-R1
          - clarifai/Kimi-K2_6
      '';
    };

    opencode-go = {
      keyFile = mkOpenAiKeyFileOpt ''
        Path to a file containing an OpenCode Go API key.
        When set, the OpenCode Go provider is registered.

        Get a key at https://opencode.ai/.

        Recommended models:
          - opencode-go/qwen3.5-plus
          - opencode-go/kimi-k2.5
          - opencode-go/deepseek-v3
      '';
    };

    # ── Azure OpenAI ────────────────────────────────────────────────────────

    azure = {
      keyFile = mkOption {
        type        = types.nullOr types.path;
        default     = null;
        example     = "/run/secrets/azure-openai-key";
        description = ''
          Path to a file containing the Azure OpenAI API key.
          When set, AZURE_API_KEY is exported and the Azure provider is registered.
        '';
      };

      endpoint = mkOption {
        type        = types.nullOr types.str;
        default     = null;
        example     = "https://my-resource.openai.azure.com";
        description = "Azure OpenAI endpoint base URL (without /openai/deployments/…).";
      };

      deployment = mkOption {
        type        = types.nullOr types.str;
        default     = null;
        example     = "gpt-4o";
        description = "Azure OpenAI deployment name.";
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
      example     = "anthropic/claude-sonnet-4-20250514";
      description = "Shorthand for <option>settings.model</option>. Takes highest priority — overrides any auto-selected default.";
    };

    share = mkOption {
      type        = types.nullOr (types.enum [ "manual" "auto" "disabled" ]);
      default     = null;
      example     = "auto";
      description = "Shorthand for \u003coption\u003esettings.share\u003c/option\u003e. Controls session sharing behavior: manual, auto, or disabled.";
    };

    autoupdate = mkOption {
      type        = types.nullOr (types.either types.bool (types.enum [ "notify" ]));
      default     = null;
      example     = "notify";
      description = "Shorthand for \u003coption\u003esettings.autoupdate\u003c/option\u003e. Set to false to disable, \"notify\" to be notified without auto-installing.";
    };

    smallModel = mkOption {
      type        = types.nullOr types.str;
      default     = null;
      example     = "anthropic/claude-haiku-4-5";
      description = "Shorthand for \u003coption\u003esettings.small_model\u003c/option\u003e. A cheaper model for lightweight tasks like title generation.";
    };

    defaultAgent = mkOption {
      type        = types.nullOr types.str;
      default     = null;
      example     = "plan";
      description = "Shorthand for \u003coption\u003esettings.default_agent\u003c/option\u003e. Default agent to use when none is specified. Must be a primary agent (not a subagent).";
    };

    shell = mkOption {
      type        = types.nullOr types.str;
      default     = null;
      example     = "zsh";
      description = "Shorthand for \u003coption\u003esettings.shell\u003c/option\u003e. Shell used for the interactive terminal and agent tool calls.";
    };

    snapshot = mkOption {
      type        = types.nullOr types.bool;
      default     = null;
      description = "Shorthand for \u003coption\u003esettings.snapshot\u003c/option\u003e. Whether to track file changes during agent operations (enables undo/revert).";
    };

    # ── Pass-throughs ────────────────────────────────────────────────────────

    settings = mkOption {
      type        = (pkgs.formats.json {}).type;
      default     = {};
      description = "Verbatim JSON written to \$XDG_CONFIG_HOME/opencode/config.json.";
    };

    context = mkOption {
      type        = types.either types.lines types.path;
      default     = "";
      description = "Global instructions written to \$XDG_CONFIG_HOME/opencode/context.md.";
    };

    commands = mkOption {
      type        = types.attrsOf (types.either types.lines types.path);
      default     = {};
      description = "Custom slash-commands.";
    };

    agents = mkOption {
      type        = types.attrsOf (types.submodule {
        options = {
          model = mkOption {
            type        = types.str;
            example     = "anthropic/claude-sonnet-4-20250514";
            description = "The model to use for this agent.";
          };
          mode = mkOption {
            type        = types.enum [ "primary" "subagent" ];
            example     = "primary";
            description = "Agent mode: primary or subagent.";
          };
          temperature = mkOption {
            type        = types.nullOr types.float;
            default     = null;
            example     = 0.1;
            description = "Temperature for the agent (optional).";
          };
          steps = mkOption {
            type        = types.nullOr types.ints.positive;
            default     = null;
            example     = 10;
            description = "Number of steps for the agent (optional).";
          };
          permission = mkOption {
            type        = types.nullOr (types.submodule {
              options = {
                edit = mkOption {
                  type        = types.nullOr (types.enum [ "allow" "deny" "ask" ]);
                  default     = null;
                  description = "Permission for file edits.";
                };
                bash = mkOption {
                  type        = types.nullOr (types.enum [ "allow" "deny" "ask" ]);
                  default     = null;
                  description = "Permission for bash commands.";
                };
              };
            });
            default     = null;
            description = "Permission settings for the agent.";
          };
        };
      });
      default     = {};
      example     = {
        plan = {
          model       = "opencode-go/qwen3.5-plus";
          mode        = "primary";
          temperature = 0.1;
          steps       = 10;
          permission  = { edit = "deny"; bash = "deny"; };
        };
      };
      description = "Agent configurations. Each key is an agent name.";
    };

    themes = mkOption {
      type        = types.attrsOf (types.either (pkgs.formats.json {}).type types.path);
      default     = {};
      description = "Custom colour themes.";
    };

    tui = mkOption {
      type        = (pkgs.formats.json {}).type;
      default     = {};
      example     = {
        theme = "system";
        keybinds = { leader = "alt+b"; };
        scroll_speed = 3;
      };
      description = "TUI-specific configuration written to \u0024XDG_CONFIG_HOME/opencode/tui.json.";
    };

    skills = mkOption {
      type        = types.attrsOf (types.either types.lines (types.either types.path types.str));
      default     = {};
      description = "Custom skills. See https://opencode.ai/docs/skills/.";
    };

    tools = mkOption {
      type        = types.attrsOf (types.either types.lines types.path);
      default     = {};
      description = "Custom tools. See https://opencode.ai/docs/tools/.";
    };

    mcp = mkOption {
      type        = (pkgs.formats.json {}).type;
      default     = {};
      example     = {
        nixos = {
          enabled = true;
          type = "local";
          command = [ "uvx" "mcp-nixos" ];
        };
      };
      description = ''
        MCP (Model Context Protocol) server configurations.
        See https://opencode.ai/docs/mcp-servers.

        Each server should have:
        - enabled: Boolean to enable/disable the server
        - type: "local" or "remote"
        - command: Array of command and arguments (e.g., [ "uvx" "mcp-nixos" ])
        - environment: (optional) Environment variables for the server
      '';
    };

    extraPackages = mkOption {
      type        = types.listOf types.package;
      default     = [];
      example     = lib.literalExpression "[ pkgs.uv pkgs.nodejs ]";
      description = "Extra packages added to the PATH available to OpenCode.";
    };
  };
}
