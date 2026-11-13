{ lib, ... }:
{
  imports = [
    ./options.nix
    ./config.nix
    ./theme.nix
    ./tests.nix
  ];
}
