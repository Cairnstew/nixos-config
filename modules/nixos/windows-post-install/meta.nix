{
  name = "windows-post-install";
  description = "Post-install EFI boot order recovery for dual-boot Windows+NixOS";
  tags = [ "windows" "dual-boot" "efi" "grub" ];
  provides = [ "my.services.windowsPostInstall" ];
}
