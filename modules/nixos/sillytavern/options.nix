{ lib, pkgs, config, ... }:
let
  instructType = lib.types.submodule {
    options = {
      input_sequence = lib.mkOption { type = lib.types.str; default = "<|im_start|>user"; };
      input_suffix = lib.mkOption { type = lib.types.str; default = "<|im_end|>\n"; };
      output_sequence = lib.mkOption { type = lib.types.str; default = "<|im_start|>assistant"; };
      output_suffix = lib.mkOption { type = lib.types.str; default = "<|im_end|>\n"; };
      system_sequence = lib.mkOption { type = lib.types.str; default = "<|im_start|>system"; };
      system_suffix = lib.mkOption { type = lib.types.str; default = "<|im_end|>\n"; };
      last_system_sequence = lib.mkOption { type = lib.types.str; default = ""; };
      first_input_sequence = lib.mkOption { type = lib.types.str; default = ""; };
      first_output_sequence = lib.mkOption { type = lib.types.str; default = ""; };
      last_input_sequence = lib.mkOption { type = lib.types.str; default = ""; };
      last_output_sequence = lib.mkOption { type = lib.types.str; default = ""; };
      story_string_prefix = lib.mkOption { type = lib.types.str; default = "<|im_start|>system"; };
      story_string_suffix = lib.mkOption { type = lib.types.str; default = "<|im_end|>\n"; };
      stop_sequence = lib.mkOption { type = lib.types.str; default = "<|im_end|>"; };
      wrap = lib.mkOption { type = lib.types.bool; default = true; };
      macro = lib.mkOption { type = lib.types.bool; default = true; };
      names_behavior = lib.mkOption { type = lib.types.str; default = "force"; };
      activation_regex = lib.mkOption { type = lib.types.str; default = ""; };
      user_alignment_message = lib.mkOption { type = lib.types.str; default = ""; };
      system_same_as_user = lib.mkOption { type = lib.types.bool; default = false; };
      sequences_as_stop_strings = lib.mkOption { type = lib.types.bool; default = true; };
      skip_examples = lib.mkOption { type = lib.types.bool; default = false; };
    };
  };

  contextType = lib.types.submodule {
    options = {
      story_string = lib.mkOption {
        type = lib.types.str;
        default = "{{#if anchorBefore}}{{anchorBefore}}\n{{/if}}{{#if system}}{{system}}\n{{/if}}{{#if wiBefore}}{{wiBefore}}\n{{/if}}{{#if description}}{{description}}\n{{/if}}{{#if personality}}{{personality}}\n{{/if}}{{#if scenario}}{{scenario}}\n{{/if}}{{#if wiAfter}}{{wiAfter}}\n{{/if}}{{#if persona}}{{persona}}\n{{/if}}{{#if anchorAfter}}{{anchorAfter}}\n{{/if}}{{trim}}";
      };
      example_separator = lib.mkOption { type = lib.types.str; default = ""; };
      chat_start = lib.mkOption { type = lib.types.str; default = ""; };
      use_stop_strings = lib.mkOption { type = lib.types.bool; default = false; };
      names_as_stop_strings = lib.mkOption { type = lib.types.bool; default = true; };
      story_string_position = lib.mkOption { type = lib.types.int; default = 0; };
      story_string_depth = lib.mkOption { type = lib.types.int; default = 1; };
      story_string_role = lib.mkOption { type = lib.types.int; default = 0; };
      always_force_name2 = lib.mkOption { type = lib.types.bool; default = true; };
      trim_sentences = lib.mkOption { type = lib.types.bool; default = false; };
      single_line = lib.mkOption { type = lib.types.bool; default = false; };
    };
  };

  syspromptType = lib.types.submodule {
    options = {
      content = lib.mkOption {
        type = lib.types.str;
        default = "Write {{char}}'s next reply in a fictional chat between {{char}} and {{user}}.";
      };
      post_history = lib.mkOption {
        type = lib.types.str;
        default = "";
      };
    };
  };

  textgenType = lib.types.submodule {
    options = {
      temp = lib.mkOption { type = lib.types.float; default = 1.0; };
      temperature_last = lib.mkOption { type = lib.types.bool; default = true; };
      top_p = lib.mkOption { type = lib.types.float; default = 0.95; };
      top_k = lib.mkOption { type = lib.types.int; default = 0; };
      top_a = lib.mkOption { type = lib.types.float; default = 0.0; };
      tfs = lib.mkOption { type = lib.types.float; default = 1.0; };
      epsilon_cutoff = lib.mkOption { type = lib.types.float; default = 0.0; };
      eta_cutoff = lib.mkOption { type = lib.types.float; default = 0.0; };
      typical_p = lib.mkOption { type = lib.types.float; default = 1.0; };
      min_p = lib.mkOption { type = lib.types.float; default = 0.01; };
      rep_pen = lib.mkOption { type = lib.types.float; default = 1.1; };
      rep_pen_range = lib.mkOption { type = lib.types.int; default = 0; };
      rep_pen_decay = lib.mkOption { type = lib.types.float; default = 0.0; };
      rep_pen_slope = lib.mkOption { type = lib.types.float; default = 1.0; };
      no_repeat_ngram_size = lib.mkOption { type = lib.types.int; default = 0; };
      penalty_alpha = lib.mkOption { type = lib.types.float; default = 0.0; };
      num_beams = lib.mkOption { type = lib.types.int; default = 1; };
      length_penalty = lib.mkOption { type = lib.types.float; default = 1.0; };
      min_length = lib.mkOption { type = lib.types.int; default = 0; };
      encoder_rep_pen = lib.mkOption { type = lib.types.float; default = 1.0; };
      freq_pen = lib.mkOption { type = lib.types.float; default = 0.0; };
      presence_pen = lib.mkOption { type = lib.types.float; default = 0.0; };
      skew = lib.mkOption { type = lib.types.float; default = 0.0; };
      do_sample = lib.mkOption { type = lib.types.bool; default = true; };
      early_stopping = lib.mkOption { type = lib.types.bool; default = false; };
      dynatemp = lib.mkOption { type = lib.types.bool; default = false; };
      min_temp = lib.mkOption { type = lib.types.float; default = 0.0; };
      max_temp = lib.mkOption { type = lib.types.float; default = 2.0; };
      dynatemp_exponent = lib.mkOption { type = lib.types.float; default = 1.0; };
      smoothing_factor = lib.mkOption { type = lib.types.float; default = 0.0; };
      smoothing_curve = lib.mkOption { type = lib.types.float; default = 1.0; };
      dry_allowed_length = lib.mkOption { type = lib.types.int; default = 2; };
      dry_multiplier = lib.mkOption { type = lib.types.float; default = 0.0; };
      dry_base = lib.mkOption { type = lib.types.float; default = 1.75; };
      dry_sequence_breakers = lib.mkOption { type = lib.types.str; default = "[\"\\n\", \":\", \"\\\"\", \"*\"]"; };
      dry_penalty_last_n = lib.mkOption { type = lib.types.int; default = 0; };
      add_bos_token = lib.mkOption { type = lib.types.bool; default = true; };
      ban_eos_token = lib.mkOption { type = lib.types.bool; default = false; };
      skip_special_tokens = lib.mkOption { type = lib.types.bool; default = true; };
      mirostat_mode = lib.mkOption { type = lib.types.int; default = 0; };
      mirostat_tau = lib.mkOption { type = lib.types.float; default = 5.0; };
      mirostat_eta = lib.mkOption { type = lib.types.float; default = 0.1; };
      guidance_scale = lib.mkOption { type = lib.types.float; default = 1.0; };
      negative_prompt = lib.mkOption { type = lib.types.str; default = ""; };
      grammar_string = lib.mkOption { type = lib.types.str; default = ""; };
      banned_tokens = lib.mkOption { type = lib.types.str; default = ""; };
      ignore_eos_token = lib.mkOption { type = lib.types.bool; default = false; };
      spaces_between_special_tokens = lib.mkOption { type = lib.types.bool; default = true; };
      speculative_ngram = lib.mkOption { type = lib.types.bool; default = false; };
      xtc_threshold = lib.mkOption { type = lib.types.float; default = 0.1; };
      xtc_probability = lib.mkOption { type = lib.types.float; default = 0.0; };
      include_reasoning = lib.mkOption { type = lib.types.bool; default = false; };
      nsigma = lib.mkOption { type = lib.types.float; default = 0.0; };
      min_keep = lib.mkOption { type = lib.types.int; default = 0; };
      adaptive_target = lib.mkOption { type = lib.types.float; default = -0.01; };
      adaptive_decay = lib.mkOption { type = lib.types.float; default = 0.9; };
      genamt = lib.mkOption { type = lib.types.int; default = 2048; };
      max_length = lib.mkOption { type = lib.types.int; default = 3520; };
      sampler_order = lib.mkOption {
        type = lib.types.listOf lib.types.int;
        default = [ 6 0 1 3 4 2 5 ];
      };
      sampler_priority = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [
          "repetition_penalty"
          "presence_penalty"
          "frequency_penalty"
          "dry"
          "temperature"
          "dynamic_temperature"
          "quadratic_sampling"
          "top_n_sigma"
          "top_k"
          "top_p"
          "typical_p"
          "epsilon_cutoff"
          "eta_cutoff"
          "tfs"
          "top_a"
          "min_p"
          "mirostat"
          "xtc"
          "encoder_repetition_penalty"
          "no_repeat_ngram"
        ];
      };
      samplers = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [
          "penalties"
          "dry"
          "top_n_sigma"
          "top_k"
          "typ_p"
          "tfs_z"
          "typical_p"
          "xtc"
          "top_p"
          "adaptive_p"
          "min_p"
          "temperature"
        ];
      };
      samplers_priorities = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [
          "dry"
          "penalties"
          "no_repeat_ngram"
          "temperature"
          "top_nsigma"
          "top_p_top_k"
          "top_a"
          "min_p"
          "tfs"
          "eta_cutoff"
          "epsilon_cutoff"
          "typical_p"
          "quadratic"
          "xtc"
        ];
      };
      logit_bias = lib.mkOption {
        type = lib.types.listOf lib.types.anything;
        default = [ ];
      };
      extensions = lib.mkOption {
        type = lib.types.attrsOf lib.types.anything;
        default = { };
      };
    };
  };

  reasoningType = lib.types.submodule {
    options = {
      prefix = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Text prepended to the reasoning block.";
      };
      suffix = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Text appended to the reasoning block.";
      };
      separator = lib.mkOption {
        type = lib.types.str;
        default = "\n";
        description = "Separator between reasoning and response.";
      };
    };
  };

  koboldType = lib.types.submodule {
    options = {
      temp = lib.mkOption { type = lib.types.float; default = 1.0; };
      rep_pen = lib.mkOption { type = lib.types.float; default = 1.1; };
      rep_pen_range = lib.mkOption { type = lib.types.int; default = 600; };
      top_p = lib.mkOption { type = lib.types.float; default = 0.95; };
      min_p = lib.mkOption { type = lib.types.float; default = 0.01; };
      top_a = lib.mkOption { type = lib.types.float; default = 0; };
      top_k = lib.mkOption { type = lib.types.int; default = 0; };
      typical = lib.mkOption { type = lib.types.float; default = 1; };
      tfs = lib.mkOption { type = lib.types.float; default = 1; };
      rep_pen_slope = lib.mkOption { type = lib.types.float; default = 0; };
      sampler_order = lib.mkOption {
        type = lib.types.listOf lib.types.int;
        default = [ 6 0 1 3 4 2 5 ];
      };
      mirostat = lib.mkOption { type = lib.types.int; default = 0; };
      mirostat_tau = lib.mkOption { type = lib.types.float; default = 5; };
      mirostat_eta = lib.mkOption { type = lib.types.float; default = 0.1; };
      use_default_badwordsids = lib.mkOption { type = lib.types.bool; default = false; };
      grammar = lib.mkOption { type = lib.types.str; default = ""; };
    };
  };

  openaiPromptSectionType = lib.types.submodule {
    options = {
      identifier = lib.mkOption {
        type = lib.types.str;
        description = "Unique identifier (main, nsfw, jailbreak, chatHistory, etc.).";
      };
      name = lib.mkOption {
        type = lib.types.str;
        description = "Display name";
      };
      system_prompt = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether this goes into system prompt.";
      };
      role = lib.mkOption {
        type = lib.types.nullOr (lib.types.enum [ "system" "user" "assistant" ]);
        default = "system";
        description = "Role for this section.";
      };
      content = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Prompt text content.";
      };
      marker = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Marker for dynamic insertion point.";
      };
    };
  };

  openaiType = lib.types.submodule {
    freeformType = with lib.types; attrsOf anything;
    options = {
      chat_completion_source = lib.mkOption {
        type = lib.types.enum [ "openai" "claude" "openrouter" "custom" "google" "vertexai" "mistralai" "minimax" "electronhub" "chutes" "ai21" ];
        default = "openai";
        description = "API backend source.";
      };
      temperature = lib.mkOption { type = lib.types.float; default = 1.0; };
      frequency_penalty = lib.mkOption { type = lib.types.float; default = 0; };
      presence_penalty = lib.mkOption { type = lib.types.float; default = 0; };
      top_p = lib.mkOption { type = lib.types.float; default = 1; };
      top_k = lib.mkOption { type = lib.types.int; default = 0; };
      max_context = lib.mkOption { type = lib.types.int; default = 4095; };
      max_tokens = lib.mkOption { type = lib.types.int; default = 300; };
      stream = lib.mkOption { type = lib.types.bool; default = true; };
      seed = lib.mkOption { type = lib.types.int; default = -1; };
      n = lib.mkOption { type = lib.types.int; default = 1; description = "Number of responses to generate."; };
      prompts = lib.mkOption {
        type = lib.types.listOf openaiPromptSectionType;
        default = [ ];
        description = "Prompt section definitions.";
      };
      prompt_order = lib.mkOption {
        type = lib.types.listOf (lib.types.submodule {
          options = {
            identifier = lib.mkOption { type = lib.types.str; };
            enabled = lib.mkOption { type = lib.types.bool; default = true; };
          };
        });
        default = [ ];
        description = "Default prompt section ordering.";
      };
      send_if_empty = lib.mkOption { type = lib.types.str; default = ""; };
      impersonation_prompt = lib.mkOption { type = lib.types.str; default = ""; };
      new_chat_prompt = lib.mkOption { type = lib.types.str; default = "[Start a new Chat]"; };
      new_group_chat_prompt = lib.mkOption { type = lib.types.str; default = ""; };
      new_example_chat_prompt = lib.mkOption { type = lib.types.str; default = ""; };
      continue_nudge_prompt = lib.mkOption { type = lib.types.str; default = ""; };
      assistant_prefill = lib.mkOption { type = lib.types.str; default = ""; };
      use_sysprompt = lib.mkOption { type = lib.types.bool; default = false; };
      squash_system_messages = lib.mkOption { type = lib.types.bool; default = false; };
      reverse_proxy = lib.mkOption { type = lib.types.str; default = ""; };
      show_external_models = lib.mkOption { type = lib.types.bool; default = false; };
      bypass_status_check = lib.mkOption { type = lib.types.bool; default = false; };
      wi_format = lib.mkOption { type = lib.types.str; default = "{0}"; };
      bias_preset_selected = lib.mkOption { type = lib.types.str; default = "Default (none)"; };
    };
  };

  themeType = lib.types.submodule {
    freeformType = with lib.types; attrsOf anything;
    options = {
      name = lib.mkOption {
        type = lib.types.str;
        description = "Theme name.";
      };
      blur_strength = lib.mkOption { type = lib.types.int; default = 10; };
      main_text_color = lib.mkOption { type = lib.types.str; default = "rgba(220, 220, 210, 1)"; };
      italics_text_color = lib.mkOption { type = lib.types.str; default = "rgba(145, 145, 145, 1)"; };
      underline_text_color = lib.mkOption { type = lib.types.str; default = "rgba(188, 231, 207, 1)"; };
      quote_text_color = lib.mkOption { type = lib.types.str; default = "rgba(225, 138, 36, 1)"; };
      blur_tint_color = lib.mkOption { type = lib.types.str; default = "rgba(23, 23, 23, 1)"; };
      chat_tint_color = lib.mkOption { type = lib.types.str; default = "rgba(23, 23, 23, 1)"; };
      user_mes_blur_tint_color = lib.mkOption { type = lib.types.str; default = "rgba(30, 30, 30, 0.9)"; };
      bot_mes_blur_tint_color = lib.mkOption { type = lib.types.str; default = "rgba(30, 30, 30, 0.9)"; };
      shadow_color = lib.mkOption { type = lib.types.str; default = "rgba(0, 0, 0, 1)"; };
      shadow_width = lib.mkOption { type = lib.types.int; default = 2; };
      font_scale = lib.mkOption { type = lib.types.float; default = 1.0; };
      fast_ui_mode = lib.mkOption { type = lib.types.bool; default = false; };
      waifuMode = lib.mkOption { type = lib.types.bool; default = false; };
      avatar_style = lib.mkOption { type = lib.types.int; default = 0; };
      chat_display = lib.mkOption { type = lib.types.int; default = 0; };
      noShadows = lib.mkOption { type = lib.types.bool; default = true; };
      chat_width = lib.mkOption { type = lib.types.int; default = 50; };
      timer_enabled = lib.mkOption { type = lib.types.bool; default = false; };
      timestamps_enabled = lib.mkOption { type = lib.types.bool; default = true; };
      timestamp_model_icon = lib.mkOption { type = lib.types.bool; default = true; };
      hideChatAvatars_enabled = lib.mkOption { type = lib.types.bool; default = false; };
      hotswap_enabled = lib.mkOption { type = lib.types.bool; default = true; };
      enableZenSliders = lib.mkOption { type = lib.types.bool; default = false; };
      enableLabMode = lib.mkOption { type = lib.types.bool; default = false; };
      reduced_motion = lib.mkOption { type = lib.types.bool; default = false; };
      compact_input_area = lib.mkOption { type = lib.types.bool; default = false; };
      custom_css = lib.mkOption { type = lib.types.str; default = ""; };
    };
  };

  quickReplySlotType = lib.types.submodule {
    options = {
      label = lib.mkOption { type = lib.types.str; default = ""; description = "Button label."; };
      mes = lib.mkOption { type = lib.types.str; default = ""; description = "Command or message to send."; };
      enabled = lib.mkOption { type = lib.types.bool; default = true; };
    };
  };

  vectfoxType = lib.types.submodule {
    freeformType = with lib.types; attrsOf anything;
    options = {
      enable = lib.mkEnableOption "VectFox advanced RAG memory system";

      backend = lib.mkOption {
        type = lib.types.enum [ "standard" "qdrant" ];
        default = "qdrant";
        description = "Vector database backend: standard (ST built-in Vectra) or qdrant.";
      };

      qdrantUrl = lib.mkOption {
        type = lib.types.str;
        default = "http://127.0.0.1:6333";
        description = "Qdrant HTTP API URL.";
      };

      qdrantGrpcUrl = lib.mkOption {
        type = lib.types.str;
        default = "http://127.0.0.1:6334";
        description = "Qdrant gRPC API URL.";
      };

      embeddingProvider = lib.mkOption {
        type = lib.types.enum [ "sillytavern" "openai" "ollama" "webllm" ];
        default = "sillytavern";
        description = "Embedding provider for VectFox.";
      };
    };
  };

  thirdPartyExtensionType = lib.types.submodule {
    freeformType = with lib.types; attrsOf anything;
    options = {
      enable = lib.mkEnableOption "this third-party extension";
      src = lib.mkOption {
        type = lib.types.nullOr lib.types.package;
        default = null;
        description = "Fetched source derivation. Required if the extension ID is not in the official index.";
      };
      rev = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Git revision (required when src is not provided and ID is in the official index).";
      };
      hash = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Nix SRI hash (required when src is not provided and ID is in the official index).";
      };
    };
  };

  ollamaModelType = lib.types.submodule {
    freeformType = with lib.types; attrsOf anything;
    options = {
      preset = lib.mkOption {
        type = lib.types.str;
        default = "Default";
        description = "TextGen sampler preset to use for this model.";
      };
      sysprompt = lib.mkOption {
        type = lib.types.str;
        default = "Neutral - Chat";
        description = "System prompt preset to use.";
      };
      syspromptState = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable the system prompt for this model.";
      };
      context = lib.mkOption {
        type = lib.types.str;
        default = "Default";
        description = "Context template to use.";
      };
      instruct = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Instruct template to use (null = disable).";
      };
      tokenizer = lib.mkOption {
        type = lib.types.str;
        default = "best_match";
        description = "Tokenizer to use (best_match, llama3, etc.).";
      };
      reasoningTemplate = lib.mkOption {
        type = lib.types.str;
        default = "Think XML";
        description = "Chain-of-thought reasoning template.";
      };
    };
  };
in
{
  options.my.services.sillytavern = {
    enable = lib.mkEnableOption "sillytavern";

    package = lib.mkPackageOption pkgs "sillytavern" { };

    user = lib.mkOption {
      type = lib.types.str;
      default = "sillytavern";
      description = "User account under which the web-application runs.";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "sillytavern";
      description = "Group account under which the web-application runs.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8000;
      description = "Port on which SillyTavern will listen.";
    };

    listen = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to listen on all network interfaces.";
    };

    listenAddressIPv4 = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "127.0.0.1";
      description = "Specific IPv4 address to listen on. Ignored if listen is true.";
    };

    listenAddressIPv6 = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "::1";
      description = "Specific IPv6 address to listen on. Ignored if listen is true.";
    };

    whitelistMode = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enables whitelist mode, restricting access to whitelisted IPs only.";
    };

    whitelistAddresses = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "127.0.0.1" "::1" ];
      example = [ "192.168.1.10" "10.0.0.5" ];
      description = "IP addresses allowed when whitelistMode is true.";
    };

    basicAuthMode = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable basic authentication.";
    };

    basicAuthUser = lib.mkOption {
      type = lib.types.str;
      default = "user";
      description = "Basic auth username.";
    };

    basicAuthPassword = lib.mkOption {
      type = lib.types.str;
      default = "password";
      description = "Basic auth password.";
    };

    settings = {
      ssl = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable SSL/TLS encryption.";
        };
        certPath = lib.mkOption {
          type = lib.types.str;
          default = "./certs/cert.pem";
          description = "Path to certificate (relative to server root).";
        };
        keyPath = lib.mkOption {
          type = lib.types.str;
          default = "./certs/privkey.pem";
          description = "Path to private key (relative to server root).";
        };
      };

      enableCorsProxy = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable CORS proxy middleware.";
      };

      cors = {
        enabled = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable or disable CORS middleware.";
        };
        origin = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ "null" ];
          description = "Allowed origins.";
        };
        credentials = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Allow credentials (cookies, authorization headers).";
        };
      };

      enableUserAccounts = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable multi-user mode.";
      };

      enableDiscreetLogin = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Hide user list on the login screen.";
      };

      sessionTimeout = lib.mkOption {
        type = lib.types.int;
        default = -1;
        description = "User session timeout in seconds. -1 = no expiry, 0 = expire on browser close.";
      };

      enableForwardedWhitelist = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Verify IP in forwarded headers for whitelist.";
      };

      forwardedHeaders = {
        xRealIp = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Use X-Real-IP header (common with Nginx/Caddy).";
        };
        xForwardedFor = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Use X-Forwarded-For header.";
        };
        cfConnectingIp = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Use CF-Connecting-IP header (Cloudflare).";
        };
      };

      logging = {
        enableAccessLog = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable access logging.";
        };
        minLogLevel = lib.mkOption {
          type = lib.types.int;
          default = 0;
          description = "Minimum log level. 0=DEBUG, 1=INFO, 2=WARN, 3=ERROR.";
        };
      };

      rateLimiting = {
        basicAuthMaxAttempts = lib.mkOption {
          type = lib.types.int;
          default = 5;
          description = "Max failed basic auth attempts before rate limiting. 0 = disable.";
        };
        accountsLoginMaxAttempts = lib.mkOption {
          type = lib.types.int;
          default = 5;
          description = "Max failed login attempts before rate limiting. 0 = disable.";
        };
      };

      backups = {
        common = {
          numberOfBackups = lib.mkOption {
            type = lib.types.int;
            default = 50;
            description = "Number of backups to keep for each chat and settings file.";
          };
        };
        chat = {
          enabled = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Enable automatic chat backups.";
          };
          checkIntegrity = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Verify integrity of chat files before saving.";
          };
        };
      };

      thumbnails = {
        enabled = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable thumbnail generation.";
        };
        format = lib.mkOption {
          type = lib.types.enum [ "jpg" "png" ];
          default = "jpg";
          description = "Image format of avatar thumbnails.";
        };
        quality = lib.mkOption {
          type = lib.types.int;
          default = 95;
          description = "JPG thumbnail quality (0-100).";
        };
      };

      performance = {
        lazyLoadCharacters = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable lazy loading of character cards.";
        };
        memoryCacheCapacity = lib.mkOption {
          type = lib.types.str;
          default = "100mb";
          example = "200mb";
          description = "Maximum memory for parsed character card cache.";
        };
        useDiskCache = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable disk caching for character cards.";
        };
      };

      extensions = {
        autoUpdate = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Automatically update extensions when release version changes.";
        };
        models = {
          autoDownload = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Enable automatic model download from HuggingFace.";
          };
        };
      };

      enableServerPlugins = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable server plugin loading.";
      };

      enableServerPluginsAutoUpdate = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Attempt to automatically update server plugins on startup.";
      };

      enableDownloadableTokenizers = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Allow downloading additional model tokenizers on demand.";
      };

      allowKeysExposure = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Allow secret keys exposure via API.";
      };

      skipContentCheck = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Skip new default content checks.";
      };

      enableKeepAlive = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable HTTP/HTTPS keep-alive globally.";
      };

      promptPlaceholder = lib.mkOption {
        type = lib.types.str;
        default = "[Start a new chat]";
        description = "Placeholder message for strict prompt post-processing mode.";
      };

      ollama = {
        keepAlive = lib.mkOption {
          type = lib.types.int;
          default = -1;
          description = "How long the model stays loaded. -1=indefinitely, 0=unload immediately, N=seconds.";
        };
        batchSize = lib.mkOption {
          type = lib.types.int;
          default = -1;
          description = "num_batch parameter. -1=model default, N=power of 2.";
        };
      };

      requestOverrides = lib.mkOption {
        type = lib.types.listOf (lib.types.submodule {
          options = {
            hosts = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              description = "List of host patterns to apply overrides to.";
            };
            headers = lib.mkOption {
              type = lib.types.attrsOf lib.types.str;
              default = { };
              description = "Headers to override for matching hosts.";
            };
          };
        });
        default = [ ];
        description = "API request overrides for matching hosts.";
      };
    };

    presets = {
      instruct = lib.mkOption {
        type = lib.types.attrsOf instructType;
        default = { };
        description = "Instruct templates written to data/default-user/instruct/<name>.json";
      };

      context = lib.mkOption {
        type = lib.types.attrsOf contextType;
        default = { };
        description = "Context templates written to data/default-user/context/<name>.json";
      };

      sysprompt = lib.mkOption {
        type = lib.types.attrsOf syspromptType;
        default = { };
        description = "System prompt presets written to data/default-user/sysprompt/<name>.json";
      };

      textgen = lib.mkOption {
        type = lib.types.attrsOf textgenType;
        default = { };
        description = "TextGen sampler presets written to data/default-user/TextGen Settings/<name>.json";
      };

      reasoning = lib.mkOption {
        type = lib.types.attrsOf reasoningType;
        default = { };
        description = "Reasoning templates written to data/default-user/reasoning/<name>.json";
      };

      kobold = lib.mkOption {
        type = lib.types.attrsOf koboldType;
        default = { };
        description = "KoboldAI presets written to data/default-user/Kobold AI Settings/<name>.json";
      };

      openai = lib.mkOption {
        type = lib.types.attrsOf openaiType;
        default = { };
        description = "OpenAI / chat completion presets written to data/default-user/OpenAI Settings/<name>.json";
      };

      themes = lib.mkOption {
        type = lib.types.attrsOf themeType;
        default = { };
        description = "UI themes written to data/default-user/themes/<name>.json";
      };

      quickReplies = lib.mkOption {
        type = lib.types.attrsOf (lib.types.submodule {
          options = {
            quickReplyEnabled = lib.mkOption { type = lib.types.bool; default = true; };
            numberOfSlots = lib.mkOption { type = lib.types.int; default = 5; };
            quickReplySlots = lib.mkOption {
              type = lib.types.listOf quickReplySlotType;
              default = [ ];
            };
          };
        });
        default = { };
        description = "Quick reply presets written to data/default-user/quick-replies/<name>.json";
      };

      activationScript = lib.mkOption {
        type = lib.types.package;
        readOnly = true;
        internal = true;
        description = "Generated script that installs all preset files. Consumed by the parent module's ExecStartPre.";
      };
    };

    activePresets = lib.mkOption {
      type = lib.types.submodule {
        options = {
          sysprompt = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Active system prompt preset name (from presets.sysprompt). null = disabled.";
          };
          context = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Active context template preset name (from presets.context).";
          };
          instruct = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Active instruct template preset name (from presets.instruct). null = disabled.";
          };
          reasoning = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Active reasoning template preset name (from presets.reasoning).";
          };
          textgen = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Active textgen sampler preset name (from presets.textgen).";
          };
          openai = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Active OpenAI preset name (from presets.openai).";
          };
          theme = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Active theme name (from presets.themes).";
          };
        };
      };
      default = { };
      description = "Active preset selections applied to settings.json on activation.";
    };

    personas = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        freeformType = with lib.types; attrsOf anything;
        options = {
          name = lib.mkOption {
            type = lib.types.str;
            description = "Persona display name.";
          };
          avatar = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Avatar filename (e.g. 'user-default.png').";
          };
          description = lib.mkOption {
            type = lib.types.str;
            default = "";
            description = "Persona description text.";
          };
        };
      });
      default = { };
      description = "User personas stored in settings.json power_user.personas.";
    };

    extensionSettings = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = { };
      example = {
        idle = {
          enabled = true;
          timer = 120;
        };
        websearch = {
          source = "google";
          use_backticks = true;
        };
      };
      description = ''
        Extension settings merged into extension_settings in settings.json.
        Keys are extension names, values are the config for that extension.
        Merged on every service start (user UI changes persist via jq merge).
      '';
    };

    extensions = {
      vectfox = lib.mkOption {
        type = vectfoxType;
        default = { };
        description = "VectFox advanced RAG memory system extension.";
      };

      thirdParty = lib.mkOption {
        type = lib.types.attrsOf thirdPartyExtensionType;
        default = { };
        example = {
          "Extension-Idle" = {
            enable = true;
            rev = "abc123def456";
            hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
          };
          "Extension-WebSearch" = {
            enable = true;
            rev = "def789ghi012";
            hash = "sha256-BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=";
          };
        };
        description = ''
          Third-party extensions from the official SillyTavern extension index.
          For extensions listed in the index, provide just `rev` and `hash`.
          For unlisted extensions, provide `src` (a fetched derivation).
        '';
      };
    };

    ollama = {
      enable = lib.mkEnableOption "automatic Ollama API configuration";

      host = lib.mkOption {
        type = lib.types.str;
        default = "127.0.0.1";
        description = "Hostname or IP address of the Ollama instance.";
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = 11434;
        description = "Port of the Ollama instance.";
      };

      model = lib.mkOption {
        type = lib.types.str;
        default = "deepseek-coder-v2:16b";
        example = "llama3.2";
        description = "Default Ollama model to pre-select. Used when `models` is empty.";
      };

      models = lib.mkOption {
        type = lib.types.attrsOf ollamaModelType;
        default = { };
        example = {
          "deepseek-coder-v2:16b" = {
            preset = "Default";
            sysprompt = "Neutral - Chat";
          };
          "InfinityRP-v1-7B" = {
            preset = "Roleplay";
            sysprompt = "Creative Writing";
          };
        };
        description = ''
          Attrset of Ollama model connection profiles keyed by model tag.
          Each entry creates a SillyTavern connection profile and (when the Ollama
          module is also enabled) auto-pulls the model.
        '';
      };
    };
  };
}
