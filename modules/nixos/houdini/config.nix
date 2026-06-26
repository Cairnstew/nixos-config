{ config, lib, pkgs, ... }:
let
  inherit (lib) mkIf;
  cfg = config.my.programs.houdini;

  licenseScript =
    if cfg.licenseServer != null then ''
      # Configure license server
      export sesi_license="${cfg.licenseServer}"
    '' else "";
in
{
  config = mkIf cfg.enable {

    nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
      "houdini"
    ];

    environment.systemPackages = [ cfg.package ];

    environment.sessionVariables = {
      HFS = "${cfg.package}";
    } // lib.optionalAttrs (cfg.licenseServer != null) {
      sesi_license = cfg.licenseServer;
    } // cfg.extraEnv;

    environment.interactiveShellInit = ''
      # Houdini environment
      if [ -d "''${HFS:-}" ]; then
        export HOUDINI_MAJOR_RELEASE="''${HFS##*/}"
        export PATH="$HFS/bin:$PATH"
      fi
      ${licenseScript}
    '';
  };
}
