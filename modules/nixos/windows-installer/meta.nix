{
  name = "windows-installer";
  description = "Automated Windows installer on first boot — downloads ISO, configures autounattend, and sets up dual-boot";
  category = "system";
  tags = [ "windows" "dual-boot" "installer" "iso" "github-release" ];
  provides = [ "my.services.windowsInstaller" ];
  expects = [ "my.secrets" ];
  complexity = "simple";
  tested = true;
  maintainer = "seanc";
}
