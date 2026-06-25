{ flake, lib, ... }:
{
  # Disable nixpkgs's built-in sillytavern module — we use the upstream
  # one from github:Cairnstew/SillyTavern instead.
  disabledModules = [ "services/web-apps/sillytavern.nix" ];

  imports = [
    # Import the upstream module WITH overlay (nixosModules.default vs
    # nixosModules.sillytavern) so that pkgs.sillytavern uses the flake's
    # package.nix, which includes the node-persist EISDIR fix.
    flake.inputs.sillytavern.nixosModules.default
    ./config.nix
  ];
  # nixosModules.default already includes sillytavern AND adds the overlay
}
