{ config, lib, pkgs, ... }:

{

	environment.systemPackages = with pkgs; [
	    spotify
	];
	
    # Local files sync
    networking.firewall.allowedTCPPorts = [ 57621 ];

    # Spotify Connect / Google Cast discovery (mDNS)
    networking.firewall.allowedUDPPorts = [ 5353 ];
}
