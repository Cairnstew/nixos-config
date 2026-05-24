{ config, lib, ... }:

let
  cfg = config.my.programs.ghostty;
in
{
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.fontSize > 0;
        message = "my.programs.ghostty.fontSize must be positive.";
      }
      {
        assertion = cfg.windowWidth > 0;
        message = "my.programs.ghostty.windowWidth must be positive.";
      }
      {
        assertion = cfg.windowHeight > 0;
        message = "my.programs.ghostty.windowHeight must be positive.";
      }
      {
        assertion = cfg.theme != "";
        message = "my.programs.ghostty.theme must not be empty.";
      }
    ];
  };
}
