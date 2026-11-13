# Proxy module (F9c split): import manifest only.
# dashboard.nix (dashboard HTML) and services.nix (systemd units) are plain
# function files imported from config.nix — NOT modules — so they are
# deliberately absent from this imports list. theme.nix IS a module: it owns
# `my.services.proxy.dashboard.theme` and the generated stylesheet.
{ ... }:
{
  imports = [
    ./options.nix
    ./config.nix
    ./theme.nix
    ./tests.nix
  ];
}
