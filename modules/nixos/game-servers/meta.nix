{
  name = "game-servers";
  description = "Steam/generic dedicated game server management via steamcmd — declarative per-server systemd units, auto-updates, firewall, and A2S Prometheus monitoring";
  category = "games";
  tags = [ "games" "steam" "steamcmd" "game-server" "gaming" "monitoring" "prometheus" "a2s" ];
  provides = [ "my.services.game-servers" ];
  expects = [ "my.networking.firewall" ];
  complexity = "complex";
  tested = true;
  maintainer = "seanc";
  homepage = "https://developer.valvesoftware.com/wiki/SteamCMD";
}
