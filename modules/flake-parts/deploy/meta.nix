{
  name = "deploy";
  description = "nixos-anywhere deploy app, VM test, and interactive deploy wizard";
  category = "deployment";
  tags = [ "deploy" "nixos-anywhere" "wizard" "vm-test" ];
  provides = [ "apps.deploy" "apps.deploy-test" "apps.deploy-wizard" ];
  complexity = "moderate";
  tested = false;
}
