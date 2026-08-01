{
  name = "mosh";
  description = "mosh (mobile shell) with tmux for session persistence over flaky links";
  category = "networking";
  tags = [ "ssh" "mosh" "tmux" "remote" "resilience" ];
  provides = [ "my.services.mosh" ];
  expects = [ "my.services.ssh" "my.services.tailscale" ];
  complexity = "simple";
  tested = true;
  maintainer = "seanc";
}
