{ config, lib, ... }:

let
  cfg = config.my.programs.spotify;
in
{
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.tui.enable -> cfg.tui.package != null;
        message = "my.programs.spotify.tui.package must not be null when TUI is enabled.";
      }
    ];
  };
}
