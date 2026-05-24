{
  name = "ssh";
  description = "SSH client configuration with key generation, agent management, and match blocks";
  category = "networking";
  tags = [ "ssh" "openssh" "remote" "security" "client" ];
  provides = [ "my.services.ssh" ];
  expects = [ ];
  complexity = "medium";
  tested = true;
  homepage = "https://www.openssh.com";
  maintainer = "seanc";
}
