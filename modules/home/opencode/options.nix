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
    type = types.nullOr types.path;
    default = null;
    example = "/run/secrets/api-key";
    inherit description;
  };

  # Common keyFile option for OpenAI-compatible providers
  mkOpenAiKeyFileOpt = description: mkOption {
    type = types.nullOr types.path;
    default = null;
    example = "/run/secrets/api-key";
    description = description + ''

      Uses {file:...} substitution because opencode has a known bug where
      {env:...} does not expand for apiKey in openai-compatible providers.
    '';
  };

  # Shared agent permission types
  actionType = types.enum [ "allow" "ask" "deny" ];

  globActionType = types.either actionType (types.attrsOf actionType);

  agentPermissionSubmodule = types.submodule {
    options = {
      read = mkOption {
        type = types.nullOr globActionType;
        default = null;
        description = "Permission for reading files.";
      };
      edit = mkOption {
        type = types.nullOr globActionType;
        default = null;
        description = "Permission for file edits (write, edit, apply_patch).";
      };
      glob = mkOption {
        type = types.nullOr globActionType;
        default = null;
        description = "Permission for glob searches.";
      };
      grep = mkOption {
        type = types.nullOr globActionType;
        default = null;
        description = "Permission for grep searches.";
      };
      list = mkOption {
        type = types.nullOr globActionType;
        default = null;
        description = "Permission for listing files.";
      };
      bash = mkOption {
        type = types.nullOr globActionType;
        default = null;
        description = "Permission for bash commands. Accepts glob patterns for fine-grained control.";
      };
      task = mkOption {
        type = types.nullOr globActionType;
        default = null;
        description = "Permission for invoking subagents via the Task tool. Glob patterns match agent names.";
      };
      external_directory = mkOption {
        type = types.nullOr globActionType;
        default = null;
        description = "Permission for accessing files outside the project worktree.";
      };
      lsp = mkOption {
        type = types.nullOr globActionType;
        default = null;
        description = "Permission for LSP operations.";
      };
      skill = mkOption {
        type = types.nullOr globActionType;
        default = null;
        description = "Permission for loading skills.";
      };
      todowrite = mkOption {
        type = types.nullOr actionType;
        default = null;
        description = "Permission for writing todo items.";
      };
      webfetch = mkOption {
        type = types.nullOr actionType;
        default = null;
        description = "Permission for fetching web content.";
      };
      websearch = mkOption {
        type = types.nullOr actionType;
        default = null;
        description = "Permission for web searches.";
      };
      question = mkOption {
        type = types.nullOr actionType;
        default = null;
        description = "Permission for asking the user questions.";
      };
      doom_loop = mkOption {
        type = types.nullOr actionType;
        default = null;
        description = "Permission for recovery prompts when an agent appears stuck.";
      };
    };
  };

in
{
  options.my.programs.opencode = {

    enable = mkEnableOption "opencode – AI coding agent for the terminal";

    package = mkOption {
      type = types.nullOr types.package;
      default = pkgs.opencode;
      defaultText = literalExpression "pkgs.opencode";
      description = "The opencode package to use.";
    };

    enableMcpIntegration = mkOption {
      type = types.bool;
      default = false;
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

    # ── First-class providers (auth.json only, NOT in opencode.json provider block) ─

    opencode-go = {
      keyFile = mkKeyFileOpt ''
        Path to a file containing an OpenCode Go API key.
        Credentials are written to ~/.local/share/opencode/auth.json.
        OpenCode Go is a first-class provider and must NOT appear in
        opencode.json's provider block.

        Get a key at https://opencode.ai/.

        Recommended models:
          - opencode-go/kimi-k2.5
          - opencode-go/kimi-k2.6
          - opencode-go/qwen3.5-plus
          - opencode-go/deepseek-v4-flash
      '';
    };

    opencode-zen = {
      keyFile = mkKeyFileOpt ''
        Path to a file containing an OpenCode Zen API key.
        Credentials are written to ~/.local/share/opencode/auth.json.
        OpenCode Zen is a first-class provider and must NOT appear in
        opencode.json's provider block.
      '';
    };

    # ── Azure OpenAI ────────────────────────────────────────────────────────

    azure = {
      keyFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        example = "/run/secrets/azure-openai-key";
        description = ''
          Path to a file containing the Azure OpenAI API key.
          When set, AZURE_API_KEY is exported and the Azure provider is registered.
        '';
      };

      endpoint = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "https://my-resource.openai.azure.com";
        description = "Azure OpenAI endpoint base URL (without /openai/deployments/…).";
      };

      deployment = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "gpt-4o";
        description = "Azure OpenAI deployment name.";
      };
    };

    # ── Ollama ──────────────────────────────────────────────────────────────

    ollamaModels = mkOption {
      type = types.attrsOf types.anything;
      default = { };
      example = {
        "qwen3.5:9b" = {
          name = "qwen3.5:9b";
          tools = true;
          numCtx = 32768;
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
      type = types.str;
      default = "http://127.0.0.1:11434/v1";
      example = "http://100.64.0.1:11434/v1";
      description = "Base URL for the Ollama OpenAI-compatible endpoint.";
    };

    # ── Shorthands ───────────────────────────────────────────────────────────

    model = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "anthropic/claude-sonnet-4-20250514";
      description = "Shorthand for <option>settings.model</option>. Takes highest priority — overrides any auto-selected default.";
    };

    share = mkOption {
      type = types.nullOr (types.enum [ "manual" "auto" "disabled" ]);
      default = null;
      example = "auto";
      description = "Shorthand for \u003coption\u003esettings.share\u003c/option\u003e. Controls session sharing behavior: manual, auto, or disabled.";
    };

    autoupdate = mkOption {
      type = types.nullOr (types.either types.bool (types.enum [ "notify" ]));
      default = null;
      example = "notify";
      description = "Shorthand for \u003coption\u003esettings.autoupdate\u003c/option\u003e. Set to false to disable, \"notify\" to be notified without auto-installing.";
    };

    smallModel = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "anthropic/claude-haiku-4-5";
      description = "Shorthand for \u003coption\u003esettings.small_model\u003c/option\u003e. A cheaper model for lightweight tasks like title generation.";
    };

    defaultAgent = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "plan";
      description = "Shorthand for \u003coption\u003esettings.default_agent\u003c/option\u003e. Default agent to use when none is specified. Must be a primary agent (not a subagent).";
    };

    shell = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "zsh";
      description = "Shorthand for \u003coption\u003esettings.shell\u003c/option\u003e. Shell used for the interactive terminal and agent tool calls.";
    };

    snapshot = mkOption {
      type = types.nullOr types.bool;
      default = null;
      description = "Shorthand for \u003coption\u003esettings.snapshot\u003c/option\u003e. Whether to track file changes during agent operations (enables undo/revert).";
    };

    # ── Pass-throughs ────────────────────────────────────────────────────────

    settings = mkOption {
      type = (pkgs.formats.json { }).type;
      default = { };
      description = "Verbatim JSON written to \$XDG_CONFIG_HOME/opencode/config.json.";
    };

    context = mkOption {
      type = types.either types.lines types.path;
      default = "";
      description = "Global instructions written to \$XDG_CONFIG_HOME/opencode/context.md.";
    };

    commands = mkOption {
      type = types.attrsOf (types.either types.lines types.path);
      default = { };
      description = "Custom slash-commands.";
    };

    agents = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          model = mkOption {
            type = types.nullOr types.str;
            default = null;
            example = "anthropic/claude-sonnet-4-20250514";
            description = ''
              Model to use for this agent.
              When null, primary agents use the globally configured model and
              subagents inherit the calling agent's model.
            '';
          };
          mode = mkOption {
            type = types.nullOr (types.enum [ "primary" "subagent" "all" ]);
            default = null;
            example = "primary";
            description = ''
              Agent mode: "primary", "subagent", or "all".
              When null, defaults to "all".
            '';
          };
          description = mkOption {
            type = types.nullOr types.str;
            default = null;
            example = "Reviews code for best practices and potential issues";
            description = ''
              Brief description of what the agent does and when to use it.
              Required by opencode for all agents.
            '';
          };
          prompt = mkOption {
            type = types.nullOr (types.either types.path types.lines);
            default = null;
            example = "{file:./prompts/build.txt}";
            description = ''
              Custom system prompt for the agent. Either a path to a prompt file
              or inline Nix string content.
            '';
          };
          temperature = mkOption {
            type = types.nullOr types.float;
            default = null;
            example = 0.1;
            description = "Temperature for the agent. Lower values produce more focused responses.";
          };
          top_p = mkOption {
            type = types.nullOr types.float;
            default = null;
            example = 0.9;
            description = "Alternative to temperature for controlling response diversity.";
          };
          steps = mkOption {
            type = types.nullOr types.ints.positive;
            default = null;
            example = 10;
            description = "Maximum number of agentic iterations before forced summarization.";
          };
          disable = mkOption {
            type = types.bool;
            default = false;
            description = "When true, the agent is disabled and unavailable.";
          };
          hidden = mkOption {
            type = types.bool;
            default = false;
            description = "Hide from TUI @ autocomplete. Only applies to subagent mode agents.";
          };
          color = mkOption {
            type = types.nullOr types.str;
            default = null;
            example = "#ff6b6b";
            description = ''
              Custom color for the agent in the UI. Use a hex color (#FF5733) or
              a theme color name (primary, secondary, accent, success, warning, error, info).
            '';
          };
          permission = mkOption {
            type = types.nullOr agentPermissionSubmodule;
            default = null;
            description = "Per-agent permission overrides.";
          };
          extraOptions = mkOption {
            type = (pkgs.formats.json { }).type;
            default = { };
            example = {
              reasoningEffort = "high";
              textVerbosity = "low";
            };
            description = ''
              Additional provider-specific model options passed through directly.
              For example, reasoningEffort for OpenAI reasoning models.
            '';
          };
        };
      });
      default = { };
      example = literalExpression ''
        {
          plan = {
            model = "opencode-go/deepseek-v4-flash";
            mode = "primary";
            temperature = 0.1;
            steps = 10;
            permission = { edit = "deny"; bash = "deny"; };
          };
          code-reviewer = {
            description = "Reviews code for best practices and potential issues";
            mode = "subagent";
            model = "opencode-go/deepseek-v4-flash";
            prompt = "You are a code reviewer. Focus on security, performance, and maintainability.";
            permission = { edit = "deny"; };
          };
        }
      '';
      description = ''
        Agent configurations. Each key is an agent name.
        See https://opencode.ai/docs/agents/ for available options.
      '';
    };

    themes = mkOption {
      type = types.attrsOf (types.either (pkgs.formats.json { }).type types.path);
      default = { };
      description = "Custom colour themes.";
    };

    references = mkOption {
      type = types.attrsOf (types.coercedTo types.str (path: { inherit path; }) (types.submodule {
        options = {
          path = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "Path to a local reference directory.";
          };
          repository = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "Git URL, host/path, or GitHub owner/repo shorthand.";
          };
          branch = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "Git branch or ref (repository only).";
          };
          description = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "Guidance describing when an agent should use this reference.";
          };
          hidden = mkOption {
            type = types.bool;
            default = false;
            description = "Omit from TUI @ autocomplete.";
          };
        };
      }));
      default = { };
      example = literalExpression ''
        {
          nixos-config = {
            path = "/home/user/nixos-config";
            description = "Use for NixOS configuration details";
          };
          sdk = {
            repository = "anomalyco/opencode-sdk-js";
            branch = "main";
            description = "Use for JavaScript SDK implementation details";
          };
        }
      '';
      description = ''
        Local directories and Git repositories to make available as project references.
        See https://opencode.ai/docs/references/ for the full reference format.
      '';
    };

    tui = mkOption {
      type = (pkgs.formats.json { }).type;
      default = { };
      example = {
        theme = "system";
        keybinds = { leader = "alt+b"; };
        scroll_speed = 3;
      };
      description = "TUI-specific configuration written to \u0024XDG_CONFIG_HOME/opencode/tui.json.";
    };

    skills = mkOption {
      type = types.attrsOf (types.either types.lines (types.either types.path types.str));
      default = { };
      description = "Custom skills. See https://opencode.ai/docs/skills/.";
    };

    plugins = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [ "opencode-helicone-session" "opencode-wakatime" ];
      description = ''
        npm package names of plugins to load. Packages are installed
        automatically by opencode at startup using Bun.
        See https://opencode.ai/docs/plugins/.
      '';
    };

    pluginFiles = mkOption {
      type = types.attrsOf (types.either types.lines types.path);
      default = { };
      example = literalExpression ''
        {
          my-plugin = builtins.readFile ./my-plugin.js;
          notification = ./notification.js;
        }
      '';
      description = ''
        Local plugin JavaScript/TypeScript files. Each key becomes a file in
        <filename>$XDG_CONFIG_HOME/opencode/plugins/&lt;name&gt;.js</filename>
        (or .ts) and is auto-discovered by opencode at startup.
        See https://opencode.ai/docs/plugins/.
      '';
    };

    tools = mkOption {
      type = types.attrsOf (types.either types.lines types.path);
      default = { };
      description = "Custom tools. See https://opencode.ai/docs/tools/.";
    };

    mcp = mkOption {
      type = (pkgs.formats.json { }).type;
      default = { };
      example = {
        nixos = {
          enabled = true;
          type = "local";
          command = [ "nix" "run" "github:utensils/mcp-nixos" "--" ];
          timeout = 120000;
        };
      };
      description = ''
        MCP (Model Context Protocol) server configurations.
        See https://opencode.ai/docs/mcp-servers.

        Each server should have:
        - enabled: Boolean to enable/disable the server
        - type: "local" or "remote"
        - command: Array of command and arguments
        - timeout: (optional) Timeout in milliseconds (default: 5000)
        - environment: (optional) Environment variables for the server
      '';
    };

    extraPackages = mkOption {
      type = types.listOf types.package;
      default = [ ];
      example = lib.literalExpression "[ pkgs.mcp-nixos pkgs.nodejs ]";
      description = "Extra packages added to the PATH available to OpenCode.";
    };

    enableLsp = mkOption {
      type = types.bool;
      default = false;
      example = true;
      description = ''
        Enable Language Server Protocol (LSP) support in OpenCode.
        When enabled, nixd is added to extraPackages for Nix LSP support.
        See https://opencode.ai/docs/lsp/ for more information.
      '';
    };

    # ── Ensemble plugin config ────────────────────────────────────────────────

    ensemble = mkOption {
      type = types.nullOr (pkgs.formats.json { }).type;
      default = null;
      example = {
        defaultModel = "opencode-go/deepseek-v4-flash";
        dashboardPort = 4747;
        mergeOnCleanup = true;
      };
      description = ''
        Configuration for the @hueyexe/opencode-ensemble plugin.
        Written to $XDG_CONFIG_HOME/opencode/ensemble.json.

        Controls model selection, rate limiting, stall detection, timeout,
        dashboard port, and auto-merge behavior for parallel agent teams.
        See https://github.com/hueyexe/opencode-ensemble for full reference.
      '';
    };

    # ── Policies ──────────────────────────────────────────────────────────────

    policies = {
      enable = mkEnableOption "opencode provider access policies (deny all, allow listed)";

      allowedProviders = mkOption {
        type = types.listOf types.str;
        default = [ ];
        example = [ "opencode-go" "opencode-zen" "clarifai" "deepinfra" ];
        description = ''
          Providers to allow when policies are enabled.
          All other providers will be denied.

          Resource names are the provider prefix from model IDs (e.g. "opencode-go"
          for "opencode-go/deepseek-v4-flash").
        '';
      };

      extraPolicies = mkOption {
        type = types.listOf (types.submodule {
          options = {
            effect = mkOption {
              type = types.enum [ "allow" "deny" ];
              description = "Whether to allow or deny the action.";
            };
            action = mkOption {
              type = types.str;
              default = "provider.use";
              description = "The action this policy controls.";
            };
            resource = mkOption {
              type = types.str;
              description = "The resource ID or wildcard pattern the statement applies to.";
            };
          };
        });
        default = [ ];
        description = ''
          Additional policy statements appended after the generated allow/deny rules.
          Useful for future policy actions beyond provider.use.
        '';
      };
    };
  };
}
