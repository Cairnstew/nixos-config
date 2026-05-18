{ config, lib, pkgs, ... }:

let
  inherit (lib)
    mkIf
    mkMerge
    ;

  cfg = config.my.programs.opencode;
  providers = import ./providers.nix { inherit lib cfg; };

in {
  config = mkIf cfg.enable (mkMerge [

    # Base opencode config
    {
      programs.opencode = {
        enable               = true;
        package              = cfg.package;
        enableMcpIntegration = cfg.enableMcpIntegration;
        context              = cfg.context;
        commands             = cfg.commands;
        agents               = cfg.agents;
        themes               = cfg.themes;
        settings             = cfg.settings // providers.allProviderSettings;
      };
    }

    # ── SDK-based providers: export API keys from files ─────────────────────
    (mkIf (cfg.openai.keyFile != null) {
      home.sessionVariables.OPENAI_API_KEY = "$(cat ${cfg.openai.keyFile})";
    })

    (mkIf (cfg.anthropic.keyFile != null) {
      home.sessionVariables.ANTHROPIC_API_KEY = "$(cat ${cfg.anthropic.keyFile})";
    })

    (mkIf (cfg.google.keyFile != null) {
      home.sessionVariables.GOOGLE_GENERATIVE_AI_API_KEY = "$(cat ${cfg.google.keyFile})";
    })

    (mkIf (cfg.groq.keyFile != null) {
      home.sessionVariables.GROQ_API_KEY = "$(cat ${cfg.groq.keyFile})";
    })

    (mkIf (cfg.mistral.keyFile != null) {
      home.sessionVariables.MISTRAL_API_KEY = "$(cat ${cfg.mistral.keyFile})";
    })

    (mkIf (cfg.xai.keyFile != null) {
      home.sessionVariables.XAI_API_KEY = "$(cat ${cfg.xai.keyFile})";
    })

    # ── Azure: export key + endpoint env vars ───────────────────────────────
    (mkIf (cfg.azure.keyFile != null) {
      home.sessionVariables.AZURE_API_KEY = "$(cat ${cfg.azure.keyFile})";
    })

    # ── Ollama: auto-select default model if one is tagged ──────────────────
    (mkIf (providers.defaultOllamaModel != null) {
      programs.opencode.settings.model = lib.mkDefault "ollama/${providers.defaultOllamaModel}";
    })

    # ── Shorthands (plain assignment = priority 100, overrides mkDefault) ───
    (mkIf (cfg.model      != null) { programs.opencode.settings.model      = cfg.model; })
    (mkIf (cfg.autoshare  != null) { programs.opencode.settings.autoshare  = cfg.autoshare; })
    (mkIf (cfg.autoupdate != null) { programs.opencode.settings.autoupdate = cfg.autoupdate; })

  ]);
}
