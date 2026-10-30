{ lib, ... }:
{
  imports = [
    ./options.nix
    ./tag.nix
    ./services.nix
    ./tests.nix
  ];
}
