{ config, lib, ... }:

let
  cfg = config.my.programs.spotify;
in
{
  options.my.programs.spotify = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open firewall ports for Spotify local discovery and sync (package installed via home-manager)";
    };
  };

  config = lib.mkIf cfg.enable {
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
