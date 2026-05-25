# modules/nixos/profiles/system/gaming.nix
# Gaming profile with Steam and gaming tools
{ config, lib, ... }:
let
  cfg = config.my.profiles.gaming;
in
{
  config = lib.mkIf cfg.enable {
    # ── Gaming dependencies ────────────────────────────────────────────────
    my.system.audio.enable = lib.mkDefault true;
    my.programs.steam.enable = lib.mkDefault true;
  };
}
