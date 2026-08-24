# modules/nixos/projectzomboid-server/modpacks/default.nix
# Modpack catalog. Each file in this folder defines one named modpack under
# my.services.projectZomboid.modpacks.<name>. A modpack is a clean, git-tracked
# bundle of Steam Workshop items (plus optional local mods and default server
# settings) that one or more servers can reference via
# servers.<name>.modpack. Add a new modpack by creating a file here and listing
# it in imports.
{ ... }:
{
  imports = [
    ./vanilla-plus.nix
  ];
}
