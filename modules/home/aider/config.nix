# Part of the aider module split (F9b): implementation + package override.
# Moved verbatim from the former flat file modules/home/aider.nix.
{ config
, lib
, pkgs
, ...
}:

let
  inherit (lib)
    mkIf
    optionalAttrs
    ;

  cfg = config.my.programs.aider;

  # Find the first model flagged as the aider default.
  defaultModelTag = lib.findFirst
    (tag: cfg.ollamaModels.${tag}.aider_default or false)
    null
    (lib.attrNames cfg.ollamaModels);

  usingOllama = cfg.ollamaModels != { };

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
            enableCuda = false;
            enableCublas = false;
            enableCudnn = false;
            enableCufft = false;
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
  aiderConf = (pkgs.formats.yaml { }).generate "aider-conf" (
    {
      model = aiderDefaultModel;
      auto-lint = cfg.autoLint;
      auto-test = cfg.autoTest;
    }
    // lib.optionalAttrs cfg.watch { watch-files = true; }
    // cfg.settings
  );

in
{
  # ── Implementation ─────────────────────────────────────────────────────────
  config = mkIf cfg.enable {

    home.packages = [
      (pkgs.writeShellScriptBin "aider" ''
        export OLLAMA_API_BASE="${cfg.ollamaBaseURL}"
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
