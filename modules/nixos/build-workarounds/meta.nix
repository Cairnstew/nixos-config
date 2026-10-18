{
  name = "build-workarounds";
  description = "Opt-in package overrides for upstream test suites that fail inside the Nix build sandbox";
  category = "nix";
  tags = [ "nix" "pkgs" "overlays" "build" "workaround" ];
  provides = [ "my.nixpkgs.buildWorkarounds" ];
  complexity = "simple";
  tested = false;
  maintainer = "seanc";
}
