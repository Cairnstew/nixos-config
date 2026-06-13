{ config, pkgs, lib, ... }:
let
  cfg = config.my.programs.vscode;
in
{
  config = lib.mkIf cfg.enable {
    programs.vscode = {
      enable = true;
      profiles.default = {
        extensions = cfg.extensions
          ++ cfg.additionalExtensions
          ++ lib.optional cfg.continue.enable pkgs.vscode-extensions.continue.continue;
      };
      profiles.default.userSettings = cfg.userSettings;
    };

    home.file.".continue/config.yaml" = lib.mkIf cfg.continue.enable {
      text =
        let
          baseConfig = {
            models = map
              (model: {
                name = model;
                provider = "ollama";
                inherit model;
                apiBase = cfg.continue.ollamaHost;
              })
              cfg.continue.models;
          };
          mergedConfig = lib.recursiveUpdate baseConfig cfg.continue.extraConfig;
        in
        builtins.readFile (
          (pkgs.formats.yaml { }).generate "continue-config" mergedConfig
        );
    };
  };
}
