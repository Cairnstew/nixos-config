# modules/nixos/projectzomboid-server/servers/default.nix
# Server catalog. Each file in this folder defines one complete server under
# my.services.projectZomboid.servers.<name>. Every server is disabled by default
# — opt in from a host config or a profile. Add a new server by creating a file
# here and listing it in imports.
{ ... }:
{
  imports = [
    ./knox.nix
  ];
}
