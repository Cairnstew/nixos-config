{
  name = "tailscale-watchdog";
  description = "Periodic Tailscale connectivity watchdog with email alerting and cooldown dedup";
  category = "networking";
  tags = [ "networking" "tailscale" "watchdog" "monitoring" "alerting" ];
  provides = [ "my.services.tailscaleWatchdog" ];
  # G5: consumes config.age.secrets.* directly (agenix-manager), not my.secrets (an enable flag only)
  expects = [ "agenix-manager" "my.homeManager" "my.services.emailAlerts" ];
  complexity = "simple";
  tested = false;
  maintainer = "seanc";
}
