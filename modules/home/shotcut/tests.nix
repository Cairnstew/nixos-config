{ config, lib, ... }:

let
  cfg = config.my.programs.shotcut;
in
{
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = lib.isDerivation cfg.package;
        message = "my.programs.shotcut.package must be a derivation.";
      }
      {
        # Guards the enable -> home.packages wiring: catches a refactor that
        # drops the package from the profile while leaving the option on.
        assertion = builtins.elem cfg.package config.home.packages;
        message = "my.programs.shotcut.enable is true but the package is not installed via home.packages.";
      }
    ];
  };
}
