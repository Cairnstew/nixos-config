{ config, lib, pkgs, ... }:

let
  inherit (lib)
    mkIf
    mkMerge
    recursiveUpdate
    ;

  cfg = config.my.programs.opencode;
  providers = import ./providers.nix { inherit lib cfg; };

  # Deep merge settings with provider settings
  # Use recursiveUpdate to merge nested attrsets properly
  mergedSettings = recursiveUpdate cfg.settings providers.allProviderSettings;

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
        tui                  = cfg.tui;
        skills               = cfg.skills;
        tools                = cfg.tools;
        extraPackages        = cfg.extraPackages;
        settings             = mergedSettings;
      };
    }

    # ── Ollama: auto-select default model if one is tagged ──────────────────
    (mkIf (providers.defaultOllamaModel != null) {
      programs.opencode.settings.model = lib.mkDefault "ollama/${providers.defaultOllamaModel}";
    })

    # ── Shorthands (plain assignment = priority 100, overrides mkDefault) ───
    (mkIf (cfg.model        != null) { programs.opencode.settings.model        = cfg.model; })
    (mkIf (cfg.share        != null) { programs.opencode.settings.share        = cfg.share; })
    (mkIf (cfg.autoupdate   != null) { programs.opencode.settings.autoupdate   = cfg.autoupdate; })
    (mkIf (cfg.smallModel   != null) { programs.opencode.settings.small_model  = cfg.smallModel; })
    (mkIf (cfg.defaultAgent != null) { programs.opencode.settings.default_agent = cfg.defaultAgent; })
    (mkIf (cfg.shell        != null) { programs.opencode.settings.shell        = cfg.shell; })
    (mkIf (cfg.snapshot     != null) { programs.opencode.settings.snapshot     = cfg.snapshot; })

  ]);
}
