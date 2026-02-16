{ lib, config, pkgs, ... }:

let
  cfg = config.my.system.bluetooth;
in
{
  options.my.system.bluetooth = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Bluetooth hardware and related packages";
    };
  };

  config = lib.mkIf cfg.enable {
    hardware.bluetooth = {
      enable = true;
      powerOnBoot = true;
    };

    environment.systemPackages = with pkgs; [
      bluez
      bluez-tools
      bluez-alsa
    ];
  };
}
