{
  name = "deploy";
  description = "Deploy ISO configuration with embedded tailscale auth key and age private key";
  category = "deployment";
  tags = [ "deploy" "live-iso" "tailscale" "secrets" ];
  provides = [ ];
  expects = [ "my.live.isos" ];
  complexity = "low";
  tested = false;
  maintainer = "seanc";
}
