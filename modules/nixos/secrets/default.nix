{ flake, ... }:
{
  imports = [
    # Import agenix module
    flake.inputs.agenix.nixosModules.default

    ./options.nix
    ./secrets.nix
    ./config.nix
    ./tests.nix
  ];
}
