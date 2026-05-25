{
  name = "spotify-player";
  description = "Terminal Spotify player with streaming, Spotify Connect, and agenix-backed authentication";
  category = "entertainment";
  tags = [ "spotify" "music" "player" "terminal" "tui" "streaming" ];
  provides = [ "my.programs.spotify" ];
  expects = [ "my.secrets" ];
  complexity = "simple";
  tested = true;
  homepage = "https://github.com/aome510/spotify-player";
  maintainer = "seanc";
}
