{ lib, ... }:
with lib;
{
  options.my.services.wsl-wm = {
    enable = mkEnableOption "xpra-based window manager on WSL2 via WSLg";

    windowManager = mkOption {
      type = types.str;
      default = "i3";
      description = "The window manager binary to launch inside xpra.";
    };

    display = mkOption {
      type = types.str;
      default = ":1";
      description = "The nested X display number xpra will create.";
    };

    xpraArgs = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Extra arguments passed to xpra start.";
    };

    extraPackages = mkOption {
      type = types.listOf types.package;
      default = [ ];
      description = "Additional packages to install alongside the window manager.";
    };
  };
}
