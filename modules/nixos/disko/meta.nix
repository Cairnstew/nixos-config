{
  name = "disko";
  description = "Dual-boot partition layout with NixOS and Windows via disko";
  category = "system";
  tags = [ "disko" "dual-boot" "partition" "windows" ];
  provides = [ "my.disko.dualBoot" ];
  expects = [ ];
  complexity = "simple";
  tested = true;
  maintainer = "seanc";
}
