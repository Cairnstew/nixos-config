# Proxy module (F9c split): import manifest only.
# dashboard.nix (dashboard HTML) and services.nix (systemd units) are plain
# function files imported from config.nix — NOT modules — so they are
# deliberately absent from this imports list.
{ ... }:
{
  imports = [
    ./options.nix
    ./config.nix
    ./tests.nix
  ];
}
