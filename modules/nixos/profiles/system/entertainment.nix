# modules/nixos/profiles/system/entertainment.nix
# Entertainment profile with media playback, gaming, and self-hosted services
{ config, lib, flake, ... }:
let
  cfg = config.my.profiles.entertainment;
  inherit (flake.config.me) username;
in
{
  config = lib.mkIf cfg.enable {
    # ── Media Playback ─────────────────────────────────────────────────
    my.system.audio.enable = lib.mkDefault true;

    # ── Gaming ─────────────────────────────────────────────────────────
    my.programs.steam.enable = lib.mkDefault true;
    my.programs.proton.enable = lib.mkDefault true;

    # ── Music ──────────────────────────────────────────────────────────
    my.programs.spotify.enable = lib.mkDefault true;

    # ── Manga Reader ─────────────────────────────────────────────────
    my.programs.moku.enable = lib.mkDefault true;

    # ── Self-Hosted Services ─────────────────────────────────────────
    my.services.sillytavern.enable = lib.mkDefault true;
    my.services.suwayomi.enable = lib.mkDefault true;
  };
}
