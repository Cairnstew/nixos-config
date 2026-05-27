{
  name = "netboot";
  description = "PXE netboot server — DHCP + TFTP + HTTP for multi-stage Windows/NixOS provisioning";
  category = "services";
  tags = [ "networking" "pxe" "netboot" "dhcp" "tftp" "dnsmasq" "nginx" "windows" "nixos" "provisioning" ];
  provides = [ "my.services.netboot" ];
  expects = [ "my.services.windowsIsoSync" ];
  complexity = "complex";
  tested = true;
  maintainer = "seanc";
}
