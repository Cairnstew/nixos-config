{
  name = "deploy";
  description = "Deploy ISO configuration with embedded tailscale auth key and age private key";
  category = "deployment";
  tags = [ "deploy" "live-iso" "tailscale" "secrets" ];
  # T7: deploy declares my.deploy (options.nix) and sets my.live.isos.deploy
  # (config.nix) — list both capabilities.
  provides = [ "my.deploy" "my.live.isos.deploy" ];
  expects = [ "my.live.isos" ];
  complexity = "low";
  tested = true;
  maintainer = "seanc";
}
