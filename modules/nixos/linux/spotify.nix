{ config, lib, pkgs, ... }:

let
  cfg = config.services.spotifyDesktop;
in
{
  options.services.spotifyDesktop = {
    enable = lib.mkEnableOption "Spotify desktop client with local discovery";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      spotify
    ];

    # Local files sync
    networking.firewall.allowedTCPPorts = [ 57621 ];

    # Spotify Connect / Google Cast discovery (mDNS)
    networking.firewall.allowedUDPPorts = [ 5353 ];
  };
}
