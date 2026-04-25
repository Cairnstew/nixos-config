# presets.nix — declarative SillyTavern preset management
#
# Imported by default.nix. Declares all preset options and produces a single
# activation script at config.my.services.sillytavern.presets.activationScript
# which default.nix splices into ExecStartPre.
#
# Files are always overwritten on activation — no "only-if-missing" logic.

{ config, lib, pkgs, ... }:

let
  cfg   = config.my.services.sillytavern;
  pcfg  = cfg.presets;

  homeDir    = "/var/lib/sillytavern";
  stUserDir  = "${homeDir}/.local/share/SillyTavern/data/default-user";

  # ---------------------------------------------------------------------------
  # Submodule type definitions
  # ---------------------------------------------------------------------------

  instructType = lib.types.submodule {
    options = {
      input_sequence            = lib.mkOption { type = lib.types.str;  default = "<|im_start|>user"; };
      input_suffix              = lib.mkOption { type = lib.types.str;  default = "<|im_end|>\n"; };
      output_sequence           = lib.mkOption { type = lib.types.str;  default = "<|im_start|>assistant"; };
      output_suffix             = lib.mkOption { type = lib.types.str;  default = "<|im_end|>\n"; };
      system_sequence           = lib.mkOption { type = lib.types.str;  default = "<|im_start|>system"; };
      system_suffix             = lib.mkOption { type = lib.types.str;  default = "<|im_end|>\n"; };
      last_system_sequence      = lib.mkOption { type = lib.types.str;  default = ""; };
      first_input_sequence      = lib.mkOption { type = lib.types.str;  default = ""; };
      first_output_sequence     = lib.mkOption { type = lib.types.str;  default = ""; };
      last_input_sequence       = lib.mkOption { type = lib.types.str;  default = ""; };
      last_output_sequence      = lib.mkOption { type = lib.types.str;  default = ""; };
      story_string_prefix       = lib.mkOption { type = lib.types.str;  default = "<|im_start|>system"; };
      story_string_suffix       = lib.mkOption { type = lib.types.str;  default = "<|im_end|>\n"; };
      stop_sequence             = lib.mkOption { type = lib.types.str;  default = "<|im_end|>"; };
      wrap                      = lib.mkOption { type = lib.types.bool; default = true; };
      macro                     = lib.mkOption { type = lib.types.bool; default = true; };
      names_behavior            = lib.mkOption { type = lib.types.str;  default = "force"; };
      activation_regex          = lib.mkOption { type = lib.types.str;  default = ""; };
      user_alignment_message    = lib.mkOption { type = lib.types.str;  default = ""; };
      system_same_as_user       = lib.mkOption { type = lib.types.bool; default = false; };
      sequences_as_stop_strings = lib.mkOption { type = lib.types.bool; default = true; };
      skip_examples             = lib.mkOption { type = lib.types.bool; default = false; };
    };
  };

  contextType = lib.types.submodule {
    options = {
      story_string = lib.mkOption {
        type    = lib.types.str;
        default = "{{#if anchorBefore}}{{anchorBefore}}\n{{/if}}{{#if system}}{{system}}\n{{/if}}{{#if wiBefore}}{{wiBefore}}\n{{/if}}{{#if description}}{{description}}\n{{/if}}{{#if personality}}{{personality}}\n{{/if}}{{#if scenario}}{{scenario}}\n{{/if}}{{#if wiAfter}}{{wiAfter}}\n{{/if}}{{#if persona}}{{persona}}\n{{/if}}{{#if anchorAfter}}{{anchorAfter}}\n{{/if}}{{trim}}";
      };
      example_separator     = lib.mkOption { type = lib.types.str;  default = ""; };
      chat_start            = lib.mkOption { type = lib.types.str;  default = ""; };
      use_stop_strings      = lib.mkOption { type = lib.types.bool; default = false; };
      names_as_stop_strings = lib.mkOption { type = lib.types.bool; default = true; };
      story_string_position = lib.mkOption { type = lib.types.int;  default = 0; };
      story_string_depth    = lib.mkOption { type = lib.types.int;  default = 1; };
      story_string_role     = lib.mkOption { type = lib.types.int;  default = 0; };
      always_force_name2    = lib.mkOption { type = lib.types.bool; default = true; };
      trim_sentences        = lib.mkOption { type = lib.types.bool; default = false; };
      single_line           = lib.mkOption { type = lib.types.bool; default = false; };
    };
  };

  syspromptType = lib.types.submodule {
    options = {
      content = lib.mkOption {
        type    = lib.types.str;
        default = "Write {{char}}'s next reply in a fictional chat between {{char}} and {{user}}.";
      };
      post_history = lib.mkOption {
        type    = lib.types.str;
        default = "";
      };
    };
  };

  textgenType = lib.types.submodule {
    options = {
      temp                          = lib.mkOption { type = lib.types.float; default = 1.0; };
      temperature_last              = lib.mkOption { type = lib.types.bool;  default = true; };
      top_p                         = lib.mkOption { type = lib.types.float; default = 0.95; };
      top_k                         = lib.mkOption { type = lib.types.int;   default = 0; };
      top_a                         = lib.mkOption { type = lib.types.float; default = 0.0; };
      tfs                           = lib.mkOption { type = lib.types.float; default = 1.0; };
      epsilon_cutoff                = lib.mkOption { type = lib.types.float; default = 0.0; };
      eta_cutoff                    = lib.mkOption { type = lib.types.float; default = 0.0; };
      typical_p                     = lib.mkOption { type = lib.types.float; default = 1.0; };
      min_p                         = lib.mkOption { type = lib.types.float; default = 0.01; };
      rep_pen                       = lib.mkOption { type = lib.types.float; default = 1.1; };
      rep_pen_range                 = lib.mkOption { type = lib.types.int;   default = 0; };
      rep_pen_decay                 = lib.mkOption { type = lib.types.float; default = 0.0; };
      rep_pen_slope                 = lib.mkOption { type = lib.types.float; default = 1.0; };
      no_repeat_ngram_size          = lib.mkOption { type = lib.types.int;   default = 0; };
      penalty_alpha                 = lib.mkOption { type = lib.types.float; default = 0.0; };
      num_beams                     = lib.mkOption { type = lib.types.int;   default = 1; };
      length_penalty                = lib.mkOption { type = lib.types.float; default = 1.0; };
      min_length                    = lib.mkOption { type = lib.types.int;   default = 0; };
      encoder_rep_pen               = lib.mkOption { type = lib.types.float; default = 1.0; };
      freq_pen                      = lib.mkOption { type = lib.types.float; default = 0.0; };
      presence_pen                  = lib.mkOption { type = lib.types.float; default = 0.0; };
      skew                          = lib.mkOption { type = lib.types.float; default = 0.0; };
      do_sample                     = lib.mkOption { type = lib.types.bool;  default = true; };
      early_stopping                = lib.mkOption { type = lib.types.bool;  default = false; };
      dynatemp                      = lib.mkOption { type = lib.types.bool;  default = false; };
      min_temp                      = lib.mkOption { type = lib.types.float; default = 0.0; };
      max_temp                      = lib.mkOption { type = lib.types.float; default = 2.0; };
      dynatemp_exponent             = lib.mkOption { type = lib.types.float; default = 1.0; };
      smoothing_factor              = lib.mkOption { type = lib.types.float; default = 0.0; };
      smoothing_curve               = lib.mkOption { type = lib.types.float; default = 1.0; };
      dry_allowed_length            = lib.mkOption { type = lib.types.int;   default = 2; };
      dry_multiplier                = lib.mkOption { type = lib.types.float; default = 0.0; };
      dry_base                      = lib.mkOption { type = lib.types.float; default = 1.75; };
      dry_sequence_breakers         = lib.mkOption { type = lib.types.str;   default = "[\"\\n\", \":\", \"\\\"\", \"*\"]"; };
      dry_penalty_last_n            = lib.mkOption { type = lib.types.int;   default = 0; };
      add_bos_token                 = lib.mkOption { type = lib.types.bool;  default = true; };
      ban_eos_token                 = lib.mkOption { type = lib.types.bool;  default = false; };
      skip_special_tokens           = lib.mkOption { type = lib.types.bool;  default = true; };
      mirostat_mode                 = lib.mkOption { type = lib.types.int;   default = 0; };
      mirostat_tau                  = lib.mkOption { type = lib.types.float; default = 5.0; };
      mirostat_eta                  = lib.mkOption { type = lib.types.float; default = 0.1; };
      guidance_scale                = lib.mkOption { type = lib.types.float; default = 1.0; };
      negative_prompt               = lib.mkOption { type = lib.types.str;   default = ""; };
      grammar_string                = lib.mkOption { type = lib.types.str;   default = ""; };
      banned_tokens                 = lib.mkOption { type = lib.types.str;   default = ""; };
      ignore_eos_token              = lib.mkOption { type = lib.types.bool;  default = false; };
      spaces_between_special_tokens = lib.mkOption { type = lib.types.bool;  default = true; };
      speculative_ngram             = lib.mkOption { type = lib.types.bool;  default = false; };
      xtc_threshold                 = lib.mkOption { type = lib.types.float; default = 0.1; };
      xtc_probability               = lib.mkOption { type = lib.types.float; default = 0.0; };
      nsigma                        = lib.mkOption { type = lib.types.float; default = 0.0; };
      min_keep                      = lib.mkOption { type = lib.types.int;   default = 0; };
      adaptive_target               = lib.mkOption { type = lib.types.float; default = -0.01; };
      adaptive_decay                = lib.mkOption { type = lib.types.float; default = 0.9; };
      genamt                        = lib.mkOption { type = lib.types.int;   default = 2048; };
      max_length                    = lib.mkOption { type = lib.types.int;   default = 3520; };
      sampler_order = lib.mkOption {
        type    = lib.types.listOf lib.types.int;
        default = [ 6 0 1 3 4 2 5 ];
      };
      sampler_priority = lib.mkOption {
        type    = lib.types.listOf lib.types.str;
        default = [
          "repetition_penalty" "presence_penalty" "frequency_penalty"
          "dry" "temperature" "dynamic_temperature" "quadratic_sampling"
          "top_n_sigma" "top_k" "top_p" "typical_p" "epsilon_cutoff"
          "eta_cutoff" "tfs" "top_a" "min_p" "mirostat" "xtc"
          "encoder_repetition_penalty" "no_repeat_ngram"
        ];
      };
      samplers = lib.mkOption {
        type    = lib.types.listOf lib.types.str;
        default = [
          "penalties" "dry" "top_n_sigma" "top_k" "typ_p" "tfs_z"
          "typical_p" "xtc" "top_p" "adaptive_p" "min_p" "temperature"
        ];
      };
      samplers_priorities = lib.mkOption {
        type    = lib.types.listOf lib.types.str;
        default = [
          "dry" "penalties" "no_repeat_ngram" "temperature" "top_nsigma"
          "top_p_top_k" "top_a" "min_p" "tfs" "eta_cutoff" "epsilon_cutoff"
          "typical_p" "quadratic" "xtc"
        ];
      };
      logit_bias = lib.mkOption {
        type    = lib.types.listOf lib.types.anything;
        default = [];
      };
      extensions = lib.mkOption {
        type    = lib.types.attrsOf lib.types.anything;
        default = {};
      };
    };
  };

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  toJsonFile = prefix: name: value:
    pkgs.writeText "sillytavern-${prefix}-${name}.json"
      (builtins.toJSON (value // { name = name; }));

  installCategory = destDir: attrset:
    lib.concatStrings (lib.mapAttrsToList (name: value:
      let file = toJsonFile destDir name value;
      in ''install -m 0644 ${file} "${stUserDir}/${destDir}/${name}.json"'' + "\n"
    ) attrset);

in
{
  options.my.services.sillytavern.presets = {

    instruct = lib.mkOption {
      type        = lib.types.attrsOf instructType;
      default     = {};
      description = "Instruct templates written to data/default-user/instruct/<name>.json";
    };

    context = lib.mkOption {
      type        = lib.types.attrsOf contextType;
      default     = {};
      description = "Context templates written to data/default-user/context/<name>.json";
    };

    sysprompt = lib.mkOption {
      type        = lib.types.attrsOf syspromptType;
      default     = {};
      description = "System prompt presets written to data/default-user/sysprompt/<name>.json";
    };

    textgen = lib.mkOption {
      type        = lib.types.attrsOf textgenType;
      default     = {};
      description = "TextGen sampler presets written to data/default-user/TextGen Settings/<name>.json";
    };

    # Internal handle consumed by default.nix — not part of the public API.
    activationScript = lib.mkOption {
      type        = lib.types.package;
      readOnly    = true;
      internal    = true;
      description = "Generated script that installs all preset files. Consumed by the parent module's ExecStartPre.";
    };
  };

  config = lib.mkIf cfg.enable {
    my.services.sillytavern.presets.activationScript =
      pkgs.writeShellScript "sillytavern-presets" ''
        set -euo pipefail

        mkdir -p "${stUserDir}/instruct"
        mkdir -p "${stUserDir}/context"
        mkdir -p "${stUserDir}/sysprompt"
        mkdir -p "${stUserDir}/TextGen Settings"

        ${installCategory "instruct"         pcfg.instruct}
        ${installCategory "context"          pcfg.context}
        ${installCategory "sysprompt"        pcfg.sysprompt}
        ${installCategory "TextGen Settings" pcfg.textgen}

        chown -R ${cfg.user}:${cfg.group} \
          "${stUserDir}/instruct"          \
          "${stUserDir}/context"           \
          "${stUserDir}/sysprompt"         \
          "${stUserDir}/TextGen Settings"
      '';
  };
}
