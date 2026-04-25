# modules/my/programs/opencode.nix
{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib)
    mkEnableOption
    mkIf
    mkMerge
    mkOption
    types
    ;

  cfg = config.my.programs.opencode;
in
{
  options.my.programs.opencode = {

    enable = mkEnableOption "opencode – AI coding agent for the terminal";

    package = mkOption {
      type        = types.nullOr types.package;
      default     = pkgs.opencode;
      defaultText = lib.literalExpression "pkgs.opencode";
      description = "The opencode package to use.";
    };

    enableMcpIntegration = mkOption {
      type        = types.bool;
      default     = false;
      description = "Forward programs.mcp.servers into opencode's MCP configuration.";
    };

    # ── Shorthand options ─────────────────────────────────────────────────

    model = mkOption {
      type        = types.nullOr types.str;
      default     = null;
      example     = "anthropic/claude-sonnet-4-20250514";
      description = "Shorthand for settings.model.";
    };

    autoshare = mkOption {
      type        = types.nullOr types.bool;
      default     = null;
      description = "Shorthand for settings.autoshare.";
    };

    autoupdate = mkOption {
      type        = types.nullOr types.bool;
      default     = null;
      description = "Shorthand for settings.autoupdate.";
    };

    # ── Pass-throughs ─────────────────────────────────────────────────────

    settings = mkOption {
      type        = (pkgs.formats.json {}).type;
      default     = {};
      description = "Verbatim JSON config written to $XDG_CONFIG_HOME/opencode/config.json.";
    };

    rules = mkOption {
      type        = types.either types.lines types.path;
      default     = "";
      description = "Global custom instructions written to $XDG_CONFIG_HOME/opencode/AGENTS.md.";
    };

    commands = mkOption {
      type    = types.attrsOf (types.either types.lines types.path);
      default = {};
      description = "Custom slash-commands.";
    };

    agents = mkOption {
      type    = types.attrsOf (types.either types.lines types.path);
      default = {};
      description = "Custom agents.";
    };

    themes = mkOption {
      type    = types.attrsOf (types.either (pkgs.formats.json {}).type types.path);
      default = {};
      description = "Custom colour themes.";
    };
  };

  # ── Implementation ────────────────────────────────────────────────────────

  config = mkIf cfg.enable {
    programs.opencode = mkMerge [
      {
        enable               = true;
        package              = cfg.package;
        enableMcpIntegration = cfg.enableMcpIntegration;
        rules                = cfg.rules;
        commands             = cfg.commands;
        agents               = cfg.agents;
        themes               = cfg.themes;
        settings             = cfg.settings;
      }

      (mkIf (cfg.model      != null) { settings.model      = cfg.model; })
      (mkIf (cfg.autoshare  != null) { settings.autoshare  = cfg.autoshare; })
      (mkIf (cfg.autoupdate != null) { settings.autoupdate = cfg.autoupdate; })
    ];
  };
}