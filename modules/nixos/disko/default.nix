{ flake, ... }:
{
  imports = [
    flake.inputs.disko.nixosModules.default
    ./options.nix
    ./config.nix
    ./tests.nix
  ];
}
