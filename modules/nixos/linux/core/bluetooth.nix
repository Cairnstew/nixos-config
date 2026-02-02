{flake, lib, config, pkgs, ... }:
let
  inherit (flake.config.me) zerotier_network;
  inherit (flake.inputs) self;
in
{

  hardware = {

  	bluetooth = {
  		enable = true;
  		powerOnBoot = true;
  	};
  };

  environment.systemPackages = with pkgs; [
    bluez
    bluez-tools
    bluez-alsa
  ];

}
