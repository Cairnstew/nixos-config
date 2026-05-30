{ config, lib, pkgs, ... }:

let
  cfg = config.my.programs.helix-ide;
in
{
  config = lib.mkIf cfg.enable {
    programs.helix = {
      enable = true;
      settings = {
        theme = lib.mkDefault "catppuccin_mocha";
        mouse = lib.mkDefault true;
        bufferline = lib.mkDefault "multiple";
      };
    };

    programs.zellij = {
      enable = true;
      settings = {
        mouse_mode = lib.mkDefault true;
      };
      layouts = {
        ide = {
          text = ''
            layout {
                pane {
                    command "hx"
                }
            }
          '';
        };
      };
    };

    home.shellAliases = {
      ide = "zellij --layout ide";
    };
  };
}
