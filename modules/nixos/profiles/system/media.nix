# modules/nixos/profiles/system/media.nix
# Full *arr media stack: Prowlarr + Sonarr + Radarr + Jellyfin
{ config, lib, ... }:
let
  cfg = config.my.profiles.media;
in
{
  config = lib.mkIf cfg.enable {
    my.services.prowlarr.enable = lib.mkDefault true;
    my.services.sonarr.enable = lib.mkDefault true;
    my.services.radarr.enable = lib.mkDefault true;
    my.services.jellyfin.enable = lib.mkDefault true;
  };
}
