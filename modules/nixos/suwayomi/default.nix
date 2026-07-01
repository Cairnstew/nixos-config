{ ... }:
{
  imports = [
    ./options.nix
    ./config.nix
    ./services.nix
    ./sync-options.nix
    ./sync.nix
    ./sync-import.nix
    ./tests.nix
  ];
}
