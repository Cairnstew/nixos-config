{ lib, ... }:
{
  imports = [
    ./options.nix
    ./config.nix
    ./tests.nix
  ];
}
