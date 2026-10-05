# default.nix — import manifest only (no logic).
{ ... }:
{
  imports = [
    ./options.nix
    ./config.nix
    ./tests.nix
  ];
}
