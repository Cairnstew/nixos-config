# eduroam module — declarative eduroam (WPA2-Enterprise) via NetworkManager
# Usage: my.networking.eduroam.enable = true;
{ lib, ... }:
{
  imports = [
    ./options.nix
    ./config.nix
    ./tests.nix
  ];
}
