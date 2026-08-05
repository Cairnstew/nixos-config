# maccel CLI binary package.
#
# Extracted from config.nix during the F9d monolith split: the buildRustPackage
# expression now lives here so services.nix builds one shared binary instead of
# inlining it.  It is built from the pinned maccel flake input (flake.nix).
{ pkgs, flake, ... }:

# maccel CLI binary (built from the flake input)
pkgs.rustPlatform.buildRustPackage {
  pname = "maccel-cli";
  version = (builtins.fromTOML (builtins.readFile "${flake.inputs.maccel}/cli/Cargo.toml")).package.version;
  src = flake.inputs.maccel;
  cargoLock.lockFile = "${flake.inputs.maccel}/Cargo.lock";
  cargoBuildFlags = [ "--bin" "maccel" ];
  doCheck = false;
}
