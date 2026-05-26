{
  name = "pxe-server";
  description = "PXE boot server with DHCP (dnsmasq), TFTP, HTTP (nginx), and iPXE boot menu";
  category = "networking";
  tags = [ "networking" "pxe" "dhcp" "tftp" "ipxe" "boot" ];
  provides = [ "my.services.pxeServer" ];
  complexity = "medium";
  tested = true;
  maintainer = "seanc";
}
