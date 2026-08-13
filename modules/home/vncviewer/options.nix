{ lib, pkgs, ... }:
let
  inherit (lib) types mkOption mkEnableOption;

  connectionOptions = _: {
    options = {
      host = mkOption {
        type = types.str;
        description = "Hostname or IP of the VNC server (e.g. a tailnet name).";
        example = "server.tail685690.ts.net";
      };

      port = mkOption {
        type = types.port;
        default = 5900;
        description = "VNC server port (matches my.services.remoteGui.vnc.port).";
      };

      passwordFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = ''
          File whose first line is the VNC password. null = no password
          (rely on tailnet trust). An agenix secret path works.
        '';
        example = "/run/agenix/vnc-password";
      };

      viewOnly = mkOption {
        type = types.bool;
        default = false;
        description = "Start in view-only mode (no keyboard/mouse input).";
      };

      fullscreen = mkOption {
        type = types.bool;
        default = false;
        description = "Start in fullscreen mode.";
      };

      scale = mkOption {
        type = types.nullOr types.int;
        default = null;
        description = "Scaling percentage (e.g. 100). null = native resolution.";
        example = 100;
      };

      extraArgs = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Extra arguments passed to vncviewer.";
      };
    };
  };
in
{
  options.my.programs.vncviewer = {
    enable = mkEnableOption "VNC viewer client for viewing remote GUI apps (pairs with my.services.remoteGui)";

    package = mkOption {
      type = types.package;
      default = pkgs.tigervnc;
      defaultText = lib.literalExpression "pkgs.tigervnc";
      description = "VNC viewer package (provides the vncviewer binary).";
    };

    connections = mkOption {
      type = types.attrsOf (types.submodule connectionOptions);
      default = { };
      description = ''
        Named VNC connections. Each generates a <literal>vnc-&lt;name&gt;</literal>
        launcher script and a matching desktop entry so you can reach the remote
        GUI in one click.
      '';
      example = {
        server = {
          host = "server.tail685690.ts.net";
          port = 5900;
        };
      };
    };
  };
}
