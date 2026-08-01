{ lib, pkgs, ... }:
let
  inherit (lib) mkEnableOption mkOption types;
in
{
  options.my.services.mosh = {
    enable = mkEnableOption "mosh (mobile shell) session-persistence for flaky links";

    package = mkOption {
      type = types.package;
      default = pkgs.mosh;
      description = "mosh package to use.";
    };

    openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Open UDP 60000-61000 in the firewall so mosh works over non-trusted
        paths (ZeroTier, LAN). Defaults to false because the tailnet interface
        is already trusted; enable when mosh must also work over the
        ZeroTier/LAN fallback paths.
      '';
    };

    installTmux = mkOption {
      type = types.bool;
      default = true;
      description = "Install tmux so sessions survive disconnects (mosh + tmux = reconnect without losing work).";
    };
  };
}
