# modules/nixos/projectzomboid-server/default.nix
# Import manifest only — see modules/AGENT.md.
{ ... }:
{
  imports = [
    ./options.nix
    ./config.nix
    ./services.nix
    ./tests.nix
    ./modpacks
    ./servers
  ];
}
