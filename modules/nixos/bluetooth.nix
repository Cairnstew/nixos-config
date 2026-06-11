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

    # NixOS bluetooth module (nixpkgs) strips CAP_NET_ADMIN from the upstream
    # bluez systemd unit. Without CAP_NET_ADMIN, bluetoothd cannot perform
    # AVDTP/A2DP audio streaming — headphones pair but audio gets "Permission
    # denied (13)" on avdtp_connect_cb. Restore the upstream set.
    systemd.services.bluetooth.serviceConfig.CapabilityBoundingSet = lib.mkForce
      "CAP_NET_ADMIN CAP_NET_BIND_SERVICE";
  };
}
