{
  name = "vm";
  description = "Per-host VM configuration options — enables the flake-level VM builder to read per-host settings like memory, cores, and extraConfig for VM-only overrides";
  category = "virtualisation";
  tags = [ "vm" "qemu" "virtualisation" "testing" ];
  provides = [ "my.vm" ];
  complexity = "simple";
  tested = false;
}
