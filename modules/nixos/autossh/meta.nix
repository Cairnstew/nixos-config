{
  name = "autossh";
  description = "autossh phone-home reverse tunnel to a bastion for plain-internet SSH fallback";
  category = "networking";
  tags = [ "ssh" "autossh" "tunnel" "remote" "resilience" "bastion" ];
  provides = [ "my.services.autosshReverse" ];
  complexity = "simple";
  tested = true;
  maintainer = "seanc";
}
