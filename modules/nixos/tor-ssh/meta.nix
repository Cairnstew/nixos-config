{
  name = "tor-ssh";
  description = "Tor onion-service SSH for last-resort remote access with zero inbound ports";
  category = "networking";
  tags = [ "ssh" "tor" "onion" "remote" "resilience" "emergency" ];
  provides = [ "my.services.torSsh" ];
  expects = [ "my.services.ssh" ];
  complexity = "simple";
  tested = true;
  maintainer = "seanc";
}
