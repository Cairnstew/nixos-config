# Aider module (F9b split): import manifest only.
# Former flat file modules/home/aider.nix split into options/config side-cars.
{ ... }:
{
  imports = [
    ./options.nix
    ./config.nix
  ];
}
