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
      {
        assertion = cfg.player.enable -> cfg.player.package != null;
        message = "my.programs.spotify.player.package must not be null when player is enabled.";
      }
      {
        assertion = cfg.player.enable -> cfg.player.interval > 0;
        message = "my.programs.spotify.player.interval must be positive when player is enabled.";
      }
      {
        assertion = cfg.player.upvote.enable -> cfg.player.upvote.package != null;
        message = "my.programs.spotify.player.upvote.package must not be null when upvote is enabled.";
      }
    ];
  };
}
