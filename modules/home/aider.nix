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

  cfg = config.my.programs.aider;

  # Find the first model flagged as the aider default.
  defaultModelTag = lib.findFirst
    (tag: cfg.ollamaModels.${tag}.aider_default or false)
    null
    (lib.attrNames cfg.ollamaModels);

  usingOllama = cfg.ollamaModels != {};

  # Prefer the flagged Ollama model, then the explicit model option.
  aiderDefaultModel =
    if defaultModelTag != null
    then "ollama/${defaultModelTag}"
    else cfg.model;

  # Aider is an API client — it gains nothing from CUDA, but the global
  # cudaSupport = true flag causes its transitive deps (opencv4, whisper-cpp
  # via ffmpeg-full via pydub) to be rebuilt with CUDA, producing derivations
  # that aren't in any binary cache. Override them back to the cacheable
  # non-CUDA variants here so the flake build stays fast.
  aiderPackage =
    let
      python = pkgs.python3.override {
        packageOverrides = final: prev: {
          opencv4 = prev.opencv4.override {
            enableCuda   = false;
            enableCublas = false;
            enableCudnn  = false;
            enableCufft  = false;
          };
          pydub = prev.pydub.override {
            ffmpeg-full = pkgs.ffmpeg;
          };
        };
      };
    in
      cfg.package.override { python3Packages = python.pkgs; };



  # Build the YAML config by merging layers in priority order.
  # Plain // merge — mkMerge is a NixOS module construct and must not be used
  # inside pkgs.formats.yaml generate; it leaks merge metadata into the output.
  aiderConf = (pkgs.formats.yaml {}).generate "aider-conf" (
    {
      model     = aiderDefaultModel;
      auto-lint = cfg.autoLint;
      auto-test = cfg.autoTest;
    }
    // lib.optionalAttrs cfg.watch { watch-files = true; }
    // cfg.settings
  );

in
{
  options.my.programs.aider = {
    enable = mkEnableOption "aider – AI pair programming in your terminal";

    package = mkOption {
      type        = types.package;
      default     = pkgs.aider-chat;
      defaultText = literalExpression "pkgs.aider-chat";
      description = "The aider package to use.";
    };

    # ── Ollama integration ─────────────────────────────────────────────────

    ollamaModels = mkOption {
      type    = types.attrsOf types.anything;
      default = {};
      example = literalExpression ''
        {
          "llama3:8b" = { aider_default = true; };
          "mistral"   = {};
        }
      '';
      description = ''
        Ollama models to expose to Aider.
        Set <literal>aider_default = true</literal> on exactly one model to use
        it as the active model; otherwise <option>model</option> is used.
      '';
    };

    ollamaBaseURL = mkOption {
      type        = types.str;
      default     = "http://127.0.0.1:11434";
      example     = "http://my-gpu-box:11434";
      description = ''
        Base URL for the Ollama server.  Exported as
        <envar>OLLAMA_API_BASE</envar> so aider can reach local models via the
        <literal>ollama/&lt;tag&gt;</literal> model prefix.
      '';
    };

    # ── Shorthand options ──────────────────────────────────────────────────

    model = mkOption {
      type        = types.str;
      default     = "gpt-4o";
      example     = "claude-3-5-sonnet-20240620";
      description = ''
        Default model when no Ollama model is flagged
        <literal>aider_default = true</literal>.
      '';
    };

    autoLint = mkOption {
      type        = types.bool;
      default     = true;
      description = "Automatically lint changed files after each aider edit.";
    };

    autoTest = mkOption {
      type        = types.bool;
      default     = false;
      description = "Automatically run tests after each aider edit.";
    };

    watch = mkOption {
      type        = types.bool;
      default     = false;
      description = ''
        Enable <literal>--watch-files</literal>: aider monitors source files for
        AI comment markers and acts on them automatically.
      '';
    };

    # ── Pass-throughs ──────────────────────────────────────────────────────

    settings = mkOption {
      type        = (pkgs.formats.yaml {}).type;
      default     = {};
      example     = literalExpression ''{ dark-mode = true; vim = true; }'';
      description = ''
        Verbatim options merged into <filename>~/.aider.conf.yml</filename>.
        Values here take precedence over all shorthand options above.
        See <link xlink:href="https://aider.chat/docs/config/aider_conf.html"/>
        for the full reference.
      '';
    };

    extraArgs = mkOption {
      type        = types.listOf types.str;
      default     = [];
      example     = [ "--no-pretty" "--map-tokens" "2048" ];
      description = ''
        Extra command-line flags prepended when invoking <command>aider</command>
        via the wrapper script.  Flags that can be expressed in
        <option>settings</option> should go there; use this only for flags that
        must appear on the command line.
      '';
    };
  };

  # ── Implementation ─────────────────────────────────────────────────────────
  config = mkIf cfg.enable {

    home.packages = [
      (pkgs.writeShellScriptBin "aider" ''
        exec ${lib.getExe aiderPackage} \
          ${lib.escapeShellArgs cfg.extraArgs} \
          "$@"
      '')
    ];

    home.file.".aider.conf.yml".source = aiderConf;

    home.sessionVariables =
      optionalAttrs usingOllama {
        OLLAMA_API_BASE = cfg.ollamaBaseURL;
      };
  };
}
