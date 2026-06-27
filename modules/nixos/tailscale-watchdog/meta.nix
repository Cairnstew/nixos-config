{
  name = "tailscale-watchdog";
  description = "Periodic Tailscale connectivity watchdog with email alerting and cooldown dedup";
  category = "networking";
  tags = [ "networking" "tailscale" "watchdog" "monitoring" "alerting" ];
  provides = [ "my.services.tailscaleWatchdog" ];
  expects = [ "my.secrets" "my.homeManager" ];
  complexity = "simple";
  tested = false;
  maintainer = "seanc";
}
