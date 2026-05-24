{
  name = "ssh";
  description = "SSH server with auto-generated root key and authorized keys management";
  category = "networking";
  tags = [ "ssh" "openssh" "remote" "security" ];
  provides = [ "my.services.ssh" ];
  complexity = "simple";
  tested = true;
  maintainer = "seanc";
}
