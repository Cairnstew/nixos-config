{ config, lib, pkgs, ... }:
let
  inherit (lib) mkIf mapAttrsToList concatStringsSep optionals;
  cfg = config.my.programs.vncviewer;

  # Build the vncviewer argument list for a connection.
  mkArgs = c:
    concatStringsSep " " (builtins.filter (a: a != "") (
      (optionals (c.passwordFile != null) [ "-passwd ${c.passwordFile}" ])
      ++ (optionals c.viewOnly [ "-ViewOnly" ])
      ++ (optionals c.fullscreen [ "-FullScreen" ])
      ++ (optionals (c.scale != null) [ "-Scaling ${toString c.scale}" ])
      ++ c.extraArgs
    ));

  # One wrapper script per connection: `vnc-<name>`.
  mkWrapper = name: c:
    pkgs.writeShellScriptBin "vnc-${name}" ''
      exec ${cfg.package}/bin/vncviewer ${mkArgs c} ${c.host}:${toString c.port} "$@"
    '';

  wrappers = mapAttrsToList mkWrapper cfg.connections;

  # Desktop entries so connections appear in the app menu / launcher.
  desktopEntries = lib.listToAttrs (mapAttrsToList
    (name: c: {
      name = "vnc-${name}";
      value = {
        name = "VNC: ${name}";
        exec = "vnc-${name}";
        comment = "Connect to ${c.host}:${toString c.port}";
        categories = [ "Network" "RemoteAccess" ];
        terminal = false;
      };
    })
    cfg.connections);
in
{
  config = mkIf cfg.enable {
    home.packages = [ cfg.package ] ++ wrappers;

    xdg.desktopEntries = desktopEntries;
  };
}
