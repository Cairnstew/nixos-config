{
  name = "jellyfin";
  description = "Jellyfin media server for streaming movies, TV shows, and music";
  category = "media";
  tags = [ "jellyfin" "media" "movies" "tv" "music" "streaming" ];
  provides = [ "my.services.jellyfin" ];
  expects = [ ];
  complexity = "simple";
  tested = true;
  maintainer = "seanc";
  homepage = "https://github.com/jellyfin/jellyfin";
}
