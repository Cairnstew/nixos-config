{
  name = "live-iso";
  description = "Custom NixOS live ISO configuration options — build via packages.live-iso-<name>";
  category = "iso";
  tags = [ "live" "iso" "installer" ];
  provides = [ "my.live.isos" ];
  complexity = "simple";
  maintainer = "seanc";
}
