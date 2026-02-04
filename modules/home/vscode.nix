{ config, pkgs, lib, ... }:
let
  cfg = config.my.programs.vscode;
in
{
  options.my.programs.vscode = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Visual Studio Code with custom configuration";
    };

    #defaultEditor = lib.mkOption {
    #  type = lib.types.bool;
    #  default = false;
    #  description = "Set VSCode as the default editor";
    #};

    extensions = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = with pkgs.vscode-extensions; [
        dracula-theme.theme-dracula
        ms-python.python
        ms-toolsai.jupyter
        bbenoist.nix
        ms-vscode-remote.vscode-remote-extensionpack
      ];
      description = "VSCode extensions to install";
      example = lib.literalExpression ''
        with pkgs.vscode-extensions; [
          dracula-theme.theme-dracula
          ms-python.python
        ]
      '';
    };

    additionalExtensions = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [];
      description = "Additional VSCode extensions to install (merged with defaults)";
      example = lib.literalExpression ''
        with pkgs.vscode-extensions; [
          golang.go
          rust-lang.rust-analyzer
        ]
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    programs.vscode = {
      enable = true;
      #defaultEditor = cfg.defaultEditor;
      profiles.default = {
        extensions = cfg.extensions ++ cfg.additionalExtensions;
      };
    };
  };
}