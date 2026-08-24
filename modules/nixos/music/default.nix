# modules/nixos/music — hash-pinned music playlist downloads (my.services.music)
{ ... }:

{
  imports = [
    ./options.nix
    ./config.nix
    ./tests.nix
  ];
}
