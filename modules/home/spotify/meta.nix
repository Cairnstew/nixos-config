{
  name = "spotify";
  description = "Spotify desktop client, spotatui TUI client, or Waybar now-playing widget with optional configuration";
  category = "music";
  tags = [ "spotify" "spotatui" "music" "tui" "gui" "audio" "waybar" "now-playing" ];
  provides = [ "my.programs.spotify" "my.programs.spotify.tui" "my.programs.spotify.player" ];
  expects = [ ];
  complexity = "simple";
  tested = false;
  homepage = "https://open.spotify.com";
  maintainer = "seanc";

  # External upstream this module wraps — see modules/AGENT.md §4 (upstream schema).
  # The now-playing widget calls the spotify-playlist-manager package; upstream
  # changes go via the ensemble space (modules/home/spotify/README.md).
  upstream = {
    repo = "spotify-playlist-manager";
    mode = "wrapped";
    space = "spotify-playlist-manager";
  };
}
