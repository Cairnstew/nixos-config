{
  name = "projectzomboid-server";
  description = "Declarative Project Zomboid dedicated servers via SteamCMD (app 380870) with clean git-tracked Steam Workshop modpack definitions, per-server .ini/sandbox config, a FIFO console, and optional web console";
  category = "gaming";
  tags = [ "gaming" "project-zomboid" "steam" "steamcmd" "server" "modpack" "workshop" "ttyd" "opencode" ];
  provides = [ "my.services.projectZomboid" ];
  expects = [ "my.services.proxy" ];
  complexity = "complex";
  tested = true;
  homepage = "https://pzwiki.net/wiki/Dedicated_server";
  maintainer = "seanc";
}
