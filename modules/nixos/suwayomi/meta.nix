{
  name = "suwayomi";
  description = "Suwayomi manga reader server with HOCON config, basic auth via agenix, and firewall integration";
  category = "services";
  tags = [ "suwayomi" "manga" "media" "java" "tachiyomi" "reader" ];
  provides = [ "my.services.suwayomi" ];
  expects = [ "my.secrets" ];
  complexity = "medium";
  tested = true;
  maintainer = "seanc";
  homepage = "https://github.com/Suwayomi/Suwayomi-Server";
}
