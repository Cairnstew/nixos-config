{ flake, ... }:
{
  imports = [
    flake.inputs.tailscale-manager.nixosModules.default
    ./options.nix
    ./config.nix
    ./tests.nix
  ];
}
