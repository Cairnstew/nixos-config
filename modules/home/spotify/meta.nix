{
  name = "spotify";
  description = "Spotify desktop client, spotatui TUI client, or Waybar now-playing widget with optional configuration";
  category = "music";
  tags = [ "spotify" "spotatui" "music" "tui" "gui" "audio" "waybar" "now-playing" ];
  provides = [ "my.programs.spotify" "my.programs.spotify.tui" "my.programs.spotify.player" "my.programs.spotify.player.upvote" ];
  expects = [ ];
  complexity = "simple";
  tested = false;
  homepage = "https://open.spotify.com";
  maintainer = "seanc";

  # External upstream this module wraps — see modules/AGENT.md §4 (upstream schema).
  # The upvote waybar widget delegates to the spotify-playlist-manager package
  # (consumed via the `spotify-playlist-manager` flake input); upstream changes
  # go via the ensemble space. `nix flake lock --update-input
  # spotify-playlist-manager` after an upstream push.
  upstream = {
    repo = "spotify-playlist-manager";
    mode = "wrapped";
    space = "spotify-playlist-manager";
    flakeInput = "spotify-playlist-manager";
  };
}
