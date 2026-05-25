{ config, lib, pkgs, ... }:

let
  cfg = config.my.programs.spotify;
in
{
  options.my.programs.spotify = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Spotify and open firewall ports for local discovery and sync";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      spotify
    ];

    # Local files sync
    networking.firewall.allowedTCPPorts = [
      57621
    ];

    # Spotify Connect / Google Cast discovery (mDNS)
    networking.firewall.allowedUDPPorts = [
      5353
    ];
  };
}
