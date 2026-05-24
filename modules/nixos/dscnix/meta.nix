{
  name = "dscnix";
  description = "Generate PowerShell DSC v3 YAML configurations from NixOS module options — enables semi-managed Windows configuration via Nix";
  category = "system";
  tags = [ "windows" "dual-boot" "dsc" "configuration-management" ];
  provides = [ "my.services.dscnix" ];
  expects = [ "my.profiles" "my.system.location" ];
  complexity = "medium";
  tested = true;
  maintainer = "seanc";
}
