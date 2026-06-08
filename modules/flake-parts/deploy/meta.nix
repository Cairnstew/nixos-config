{
  name = "deploy";
  description = "nixos-anywhere deploy app, deploy-with-keys (pre-generated host key + secrets wiring), VM test, and interactive deploy wizard";
  category = "deployment";
  tags = [ "deploy" "nixos-anywhere" "host-keys" "secrets" "wizard" "vm-test" ];
  provides = [ "devShells.deploy-tool" ];
  complexity = "moderate";
  tested = false;
}
