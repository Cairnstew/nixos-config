{flake, lib, config, pkgs, ... }:
let
  inherit (flake) config inputs;
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
