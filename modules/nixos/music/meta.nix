{
  name = "music";
  description = "Hash-pinned music playlist downloads — songs declared in git as playlists, built as fixed-output derivations (like packwiz modpacks) and installed into a data dir.";
  category = "media";
  tags = [ "media" "music" "playlist" "reproducible" "fod" ];
  provides = [ "my.services.music" ];
  complexity = "medium";
  tested = true;
  maintainer = "seanc";
  autowire = {
    enable = true;
    priority = 100;
  };
}
