{
  name = "nixos-anywhere-deploy";
  description = "nixos-anywhere deploy: auto-detects disk-config.nix sidecars, generates per-host deploy and prepare-keys packages, and config build checks";
  category = "deployment";
  tags = [ "deploy" "nixos-anywhere" "disko" "host-keys" "config-build" ];
  provides = [ "packages.deploy-<host>" "packages.prepare-keys-<host>" "checks.build-<host>" "my.nixosAnywhereDeploy.hosts" ];
  complexity = "moderate";
  tested = false;
}
