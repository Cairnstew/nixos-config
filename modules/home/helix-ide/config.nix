{ config, lib, pkgs, flake, ... }:

let
  cfg = config.my.programs.helix-ide;
  scheme = flake.config.me.colorScheme or { };
in
{
  config = lib.mkIf cfg.enable {
    programs.helix = {
      enable = true;
      settings = {
        theme = lib.mkDefault (lib.replaceStrings [ "-" ] [ "_" ] (scheme.slug or "catppuccin_mocha"));

        editor = {
          mouse = lib.mkDefault true;
          bufferline = lib.mkDefault "multiple";

          line-number = if cfg.relativeLines then "relative" else "absolute";
          cursorline = true;
          color-modes = true;

          lsp = {
            display-messages = true;
            display-inlay-hints = cfg.inlayHints;
          };

          inline-diagnostics = {
            cursor-line = cfg.inlineDiagnostics;
          };

          cursor-shape = {
            normal = "block";
            insert = "bar";
            select = "underline";
          };

          indent-guides = {
            render = true;
            character = "╎";
            skip-levels = 1;
          };

          whitespace.render = {
            space = "none";
            tab = "all";
            newline = "none";
          };
        };

        keys.insert = {
          j = { k = "normal_mode"; };
        };
      };
    };

    programs.zellij = {
      enable = true;
      settings = {
        mouse_mode = lib.mkDefault true;
      };
      layouts = {
        ide = ''
          layout {
              pane {
                  command "hx"
              }
          }
        '';
      };
    };

    home.shellAliases = {
      ide = "zellij --layout ide";
    };
  };
}
