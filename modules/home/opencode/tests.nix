{ config, lib, ... }:

let
  inherit (lib) mkIf;
  cfg = config.my.programs.opencode;

  # Count how many providers are active
  activeProviders = lib.filter (p: p != null) [
    (if cfg.openai.keyFile    != null then "openai"    else null)
    (if cfg.anthropic.keyFile != null then "anthropic" else null)
    (if cfg.google.keyFile    != null then "google"    else null)
    (if cfg.groq.keyFile      != null then "groq"      else null)
    (if cfg.mistral.keyFile   != null then "mistral"   else null)
    (if cfg.xai.keyFile       != null then "xai"       else null)
    (if cfg.together.keyFile  != null then "together"  else null)
    (if cfg.openrouter.keyFile != null then "openrouter" else null)
    (if cfg.fireworks.keyFile != null then "fireworks" else null)
    (if cfg.cerebras.keyFile  != null then "cerebras"  else null)
    (if cfg.deepinfra.keyFile != null then "deepinfra" else null)
    (if cfg.clarifai.patFile  != null then "clarifai"  else null)
    (if (cfg.azure.keyFile != null && cfg.azure.endpoint != null && cfg.azure.deployment != null) then "azure" else null)
    (if cfg.ollamaModels != {} then "ollama" else null)
  ];

in {
  config = mkIf cfg.enable {
    # ── L0: Nix assertions ──────────────────────────────────────────────────
    assertions = [
      {
        assertion = cfg.model != null -> (lib.length activeProviders > 0);
        message = "my.programs.opencode: model is set but no providers are configured. "
                + "Enable at least one provider by setting its keyFile.";
      }
      {
        assertion = cfg.ollamaModels != {} -> cfg.ollamaBaseURL != "";
        message = "my.programs.opencode: ollamaModels is non-empty but ollamaBaseURL is empty.";
      }
      {
        assertion = cfg.azure.keyFile != null -> (cfg.azure.endpoint != null && cfg.azure.deployment != null);
        message = "my.programs.opencode: azure.keyFile is set but azure.endpoint and/or azure.deployment are missing.";
      }
    ];
  };
}
