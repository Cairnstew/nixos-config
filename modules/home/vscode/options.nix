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

    server = {
      enable = lib.mkEnableOption ''
        VS Code server support for Remote-SSH/WSL development.
        Note: This option only has an effect on NixOS hosts that import
        the corresponding NixOS module (nixosModules.vscode-server).
        On standalone Home Manager it is a no-op.
      '';
    };

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
    };

    additionalExtensions = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = "Additional VSCode extensions to install (merged with defaults)";
    };

    continue = {
      enable = lib.mkEnableOption "Continue AI coding assistant";

      ollamaHost = lib.mkOption {
        type = lib.types.str;
        default = "http://127.0.0.1:11434";
        description = "Ollama API base URL.";
      };

      models = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        example = [ "llama3.2" "mistral" ];
        description = "Ollama models to expose to Continue.";
      };

      extraConfig = lib.mkOption {
        type = lib.types.attrs;
        default = { };
        description = ''
          Extra configuration to merge into ~/.continue/config.yaml.
          See https://docs.continue.dev/reference for all options.
        '';
        example = lib.literalExpression ''
          {
            tabAutocompleteModel = {
              name = "starcoder2";
              provider = "ollama";
              model = "starcoder2:3b";
            };
            slashCommands = [
              { name = "share"; description = "Export conversation"; }
            ];
          }
        '';
      };
    };
  };
}
