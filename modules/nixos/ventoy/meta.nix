{
  name = "ventoy";
  description = "Ventoy USB multi-boot tool — ISO management, ventoy.json config, and deploy script";
  category = "boot";
  tags = [ "ventoy" "usb" "iso" "multiboot" ];
  # my.ventoy is also declared by options.nix — keep meta in sync
  provides = [ "my.programs.ventoy" "my.ventoy" ];
  complexity = "simple";
  tested = true;
  maintainer = "seanc";
}
