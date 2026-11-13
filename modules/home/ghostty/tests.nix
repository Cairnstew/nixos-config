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
        assertion = !cfg.theme.enable || cfg.theme.name != "";
        message = "my.programs.ghostty.theme.name must not be empty.";
      }
      {
        assertion = !cfg.theme.enable || (cfg.theme.palette ? background && cfg.theme.palette ? foreground);
        message = "ghostty theme: the resolved palette is missing background/foreground.";
      }
      {
        assertion =
          !cfg.theme.enable
          || (cfg.theme.palette ? terminal && cfg.theme.palette.terminal ? black);
        message = "ghostty theme: the resolved palette is missing the terminal/ANSI slots.";
      }
    ];
  };
}
