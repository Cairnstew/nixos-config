# modules/nixos/minecraft-server/servers/default.nix
# Server catalog. Each file in this folder defines one complete server under
# my.services.minecraftServer.servers.<name>. Add a new server by creating a
# file here and listing it in imports.
{ ... }:
{
  imports = [
    ./test.nix
  ];
}
