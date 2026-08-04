# modules/nixos/profiles/home/options.nix
# Option declarations for home-level profiles.
# Extracted from default.nix so default.nix is a pure import manifest (F5).
# Option definitions are byte-identical to the originals in default.nix.
{ lib, ... }:
{
  # Home profiles configure home-manager programs
  options.my.homeProfiles = {
    common.enable = lib.mkEnableOption "common home profile (shell, basic tools)";
    desktop.enable = lib.mkEnableOption "desktop home profile (GUI apps)";
    development.enable = lib.mkEnableOption "development home profile (dev tools)";
    minimal.enable = lib.mkEnableOption "minimal home profile (essential only)";
    server.enable = lib.mkEnableOption "server home profile (SSH tools)";
  };
}
