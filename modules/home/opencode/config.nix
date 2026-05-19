{ config, lib, pkgs, ... }:

let
  inherit (lib)
    mkIf
    mkMerge
    recursiveUpdate
    filterAttrs
    mapAttrs
    ;

  cfg = config.my.programs.opencode;
  providers = import ./providers.nix { inherit lib cfg; };

  # Transform agent config to opencode.json format
  # Filter out null values for optional fields
  mkAgentConfig = agentCfg: {
    model = agentCfg.model;
    mode  = agentCfg.mode;
  }
  // (lib.optionalAttrs (agentCfg.temperature != null) { temperature = agentCfg.temperature; })
  // (lib.optionalAttrs (agentCfg.steps != null) { steps = agentCfg.steps; })
  // (lib.optionalAttrs (agentCfg.permission != null) {
    permission = filterAttrs (_: v: v != null) {
      edit = agentCfg.permission.edit;
      bash = agentCfg.permission.bash;
    };
  });

  agentSettings = lib.optionalAttrs (cfg.agents != {}) {
    agent = mapAttrs (_: mkAgentConfig) cfg.agents;
  };

  # Deep merge settings with provider settings, mcp settings, and agent settings
  # Use recursiveUpdate to merge nested attrsets properly
  settingsWithProviders = recursiveUpdate cfg.settings providers.allProviderSettings;
  settingsWithMcp = recursiveUpdate settingsWithProviders (
    lib.optionalAttrs (cfg.mcp != {}) { inherit (cfg) mcp; }
  );
  mergedSettings = recursiveUpdate settingsWithMcp agentSettings;

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
