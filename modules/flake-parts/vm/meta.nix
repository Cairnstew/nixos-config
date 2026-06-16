{
  name = "vm";
  description = "Per-host QEMU VM builder — generates graphical and headless VM runner packages for each NixOS host, backed by the nixpkgs qemu-vm module";
  category = "virtualisation";
  tags = [ "vm" "qemu" "virtualisation" "testing" "graphical" "headless" ];
  provides = [ "my.vm" "packages.<host>-vm" "packages.<host>-vm-headless" ];
  complexity = "medium";
  tested = false;
}
