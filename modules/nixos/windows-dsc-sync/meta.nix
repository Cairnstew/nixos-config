{
  name = "windows-dsc-sync";
  description = "Sync DSC YAML config from NixOS to the Windows partition on rebuild";
  tags = [ "windows" "dual-boot" "dsc" "sync" ];
  provides = [ "my.services.windowsDscSync" ];
}
