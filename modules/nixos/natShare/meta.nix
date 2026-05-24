{
  name = "natShare";
  description = "Internet connection sharing via NAT with dnsmasq DHCP and firewall configuration";
  category = "networking";
  tags = [ "networking" "nat" "dhcp" "dnsmasq" "internet-sharing" ];
  provides = [ "my.services.natShare" ];
  complexity = "medium";
  tested = true;
  maintainer = "seanc";
}
