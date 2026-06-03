{
  name = "deploy";
  description = "nixos-anywhere deploy app, deploy-with-keys (pre-generated host key + secrets wiring), VM test, and interactive deploy wizard";
  category = "deployment";
  tags = [ "deploy" "nixos-anywhere" "host-keys" "secrets" "wizard" "vm-test" ];
  provides = [ "apps.deploy" "apps.deploy-with-keys" "apps.deploy-test" "apps.deploy-wizard" ];
  complexity = "moderate";
  tested = false;
}
