{ config, lib, ... }:

let
  cfg = config.my.programs.rstudio;
in
{
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = builtins.length cfg.rPackages > 0;
        message = "my.programs.rstudio.rPackages must not be empty.";
      }
    ];
  };
}
