{ lib, ... }:
{
  imports = [
    ./tag.nix
    ./services.nix
    ./tests.nix
  ];
}
