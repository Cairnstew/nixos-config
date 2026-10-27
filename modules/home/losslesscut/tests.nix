{ config, lib, ... }:

let
  cfg = config.my.programs.losslesscut;
in
{
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = lib.isDerivation cfg.package;
        message = "my.programs.losslesscut.package must be a derivation.";
      }
      {
        # Guards the enable -> home.packages wiring: catches a refactor that
        # drops the package from the profile while leaving the option on.
        assertion = builtins.elem cfg.package config.home.packages;
        message = "my.programs.losslesscut.enable is true but the package is not installed via home.packages.";
      }
    ];
  };
}
