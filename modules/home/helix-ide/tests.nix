{ config, lib, ... }:

let
  cfg = config.my.programs.helix-ide;
in
{
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.programs.helix.enable;
        message = "helix-ide requires programs.helix to be enabled.";
      }
      {
        assertion = config.programs.zellij.enable;
        message = "helix-ide requires programs.zellij to be enabled.";
      }
    ];
  };
}
