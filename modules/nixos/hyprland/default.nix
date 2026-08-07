{ ... }:
{
  imports = [
    ./core
    ./bar
    ./launcher
    ./notifications
    ./lockscreen
    ./screenshot
    ./clipboard
    ./portal
    ./display-manager
    ./audio
    ./utilities
    ./nvidia
    ./idle
    ./colorpicker
    ./night-light
    ./pyprland
    # standalone ./awww submodule removed (recon M3) — awww is provided by
    # ./wallpapers via wallpapers.backend = "awww"; the standalone module
    # duplicated the awww-daemon unit.
    ./wallpapers
    ./options.nix
    ./enable.nix
    ./tests.nix
  ];
}
