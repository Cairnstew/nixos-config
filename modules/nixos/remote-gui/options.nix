{ lib, flake, ... }:
let
  inherit (lib) types mkOption mkEnableOption;
in
{
  options.my.services.remoteGui = {
    enable = mkEnableOption "virtual X display (Xvfb) for running headless GUI apps, shared via x11vnc";

    display = mkOption {
      type = types.str;
      default = ":10";
      example = ":11";
      description = "Virtual X display identifier (must start with ':').";
    };

    screen = mkOption {
      type = types.str;
      default = "1920x1080x24";
      example = "2560x1440x24";
      description = "Xvfb -screen 0 geometry: WIDTHxHEIGHTxDEPTH.";
    };

    vnc = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Share the virtual display via x11vnc.";
      };

      port = mkOption {
        type = types.port;
        default = 5900;
        description = "TCP port the x11vnc server listens on.";
      };

      listenAddress = mkOption {
        type = types.str;
        default = "0.0.0.0";
        description = "Address the x11vnc server binds to. 0.0.0.0 is reachable over the tailnet because tailscale0 is a trusted firewall interface.";
      };

      passwordFile = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "File whose first line is the VNC password. null = no password (rely on tailnet trust).";
        example = "/run/agenix/vnc-password";
      };

      openFirewall = mkOption {
        type = types.bool;
        default = false;
        description = "Open the VNC port in the firewall. Not needed for the tailnet (trusted interface); set true only if LAN/ZeroTier clients must connect directly.";
      };
    };

    windowManager = mkOption {
      type = types.nullOr types.package;
      default = null;
      example = lib.literalExpression "pkgs.openbox";
      description = "Optional lightweight window manager for the virtual display (e.g. pkgs.openbox) so windows get decorations and focus.";
    };

    apps = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          command = mkOption {
            type = types.str;
            description = "Shell command that launches the app. Use an absolute path (e.g. <literal>\"\${pkgs.foo}/bin/foo\"</literal>) rather than relying on PATH.";
          };

          user = mkOption {
            type = types.str;
            default = flake.config.me.username;
            description = "System user the app runs as. Defaults to the primary user.";
          };

          autostart = mkOption {
            type = types.bool;
            default = true;
            description = "Start the app at boot on the virtual display.";
          };

          restart = mkOption {
            type = types.bool;
            default = true;
            description = "Restart the app if it exits unexpectedly.";
          };

          extraEnv = mkOption {
            type = types.attrsOf types.str;
            default = { };
            description = "Extra environment variables for the app service.";
          };
        };
      });
      default = { };
      description = "GUI apps to run on the virtual display. Each becomes a <literal>remote-gui-app-&lt;name&gt;</literal> systemd unit.";
    };
  };
}
