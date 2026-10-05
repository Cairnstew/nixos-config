# modules/nixos/projectzomboid-server/servers/default.nix
# This repo's server catalog. Each file in this folder defines one complete
# server under services.project-zomboid-servers.servers.<name>. Every server is
# disabled by default — opt in from a host config or a profile:
#
#   services.project-zomboid-servers.servers.knox.enable = true;
#
# The modpack CATALOGUE is not here: it is plain data exported by the upstream
# flake and wired in wholesale by ../config.nix, so packs are versioned with the
# upstream module rather than forked here.
{ ... }:
{
  imports = [
    ./knox.nix
  ];
}
