{ config, pkgs, lib, ... }:
let
  cfg = config.my.programs.zsh;
in
{
  options.my.programs.zsh = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Zsh shell with custom configuration";
    };

    enableAutosuggestion = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable Zsh autosuggestions";
    };

    enableSyntaxHighlighting = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable Zsh syntax highlighting";
    };

    enableViMode = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Enable Zsh vi-mode plugin.
        Note: Currently disabled by default due to bugs.
        See https://github.com/jeffreytse/zsh-vi-mode/issues/317
      '';
    };

    plugins = lib.mkOption {
      type = lib.types.listOf lib.types.attrs;
      default = [];
      description = "Additional Zsh plugins to load";
      example = lib.literalExpression ''
        [
          {
            name = "zsh-nix-shell";
            file = "nix-shell.plugin.zsh";
            src = pkgs.zsh-nix-shell;
          }
        ]
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    programs.zsh = {
      enable = true;
      autosuggestion.enable = cfg.enableAutosuggestion;
      syntaxHighlighting.enable = cfg.enableSyntaxHighlighting;
      plugins = cfg.plugins ++ lib.optionals cfg.enableViMode [
        {
          name = "vi-mode";
          src = pkgs.zsh-vi-mode;
          file = "share/zsh-vi-mode/zsh-vi-mode.plugin.zsh";
        }
      ];
    };
  };
}