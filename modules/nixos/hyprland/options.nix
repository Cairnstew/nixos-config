{ lib, pkgs, flake, ... }:
{
  options.my.desktop.hyprland = {
    enable = lib.mkEnableOption "Hyprland Wayland compositor desktop environment";

    user = lib.mkOption {
      type = lib.types.str;
      default = flake.config.me.username;
      example = "alice";
      description = "Primary user that will run the Hyprland session.";
    };


    extraPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = "Additional packages to install alongside the desktop.";
    };

    terminal = lib.mkOption {
      type = lib.types.package;
      default = pkgs.ghostty;
      defaultText = lib.literalExpression "pkgs.ghostty";
      description = "Default terminal emulator package (used for the SUPER+Return keybind, and to host the SUPER+E file manager).";
    };

    fileManager = {
      # Default-on: this option replaces the unconditional `SUPER+E → thunar`
      # bind that predates it, so leaving it false would silently drop the keybind.
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable the SUPER+E keybind that opens the terminal file manager.";
      };

      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.superfile;
        defaultText = lib.literalExpression "pkgs.superfile";
        description = ''
          Terminal file manager launched by SUPER+E. Any binary that accepts a
          directory as its first positional argument works (superfile, yazi, lf).
          A TUI cannot replace the GUI `inode/directory` handler: superfile ships
          no .desktop file, so MIME/dir-open still resolves through
          `my.system.userDefaults` (`flake.config.defaults.fileManager`).
        '';
      };

      startDirectory = lib.mkOption {
        type = lib.types.str;
        default = "/home/${flake.config.me.username}";
        defaultText = lib.literalExpression ''"/home/<flake.config.me.username>"'';
        example = "/home/alice/Downloads";
        description = ''
          Directory SUPER+E opens. Must be absolute: `ghostty -e <cmd> <args>`
          passes the rest of the argv through without a shell, so `~` would be
          taken literally.
        '';
      };
    };

    useMonitors = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Use my.monitors to generate hyprland monitor lines instead of the
        flat string list in the old desktop.hyprland.monitors option.
      '';
    };
  };
}
