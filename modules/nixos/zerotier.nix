{ config, lib, ... }:
let
  cfg = config.my.services.zerotier;
in
{
  options.my.services.zerotier = {
    enable = lib.mkEnableOption "ZeroTier system service";
    networks = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      example = [ "8056c2e21c000001" ];
      description = ''
        List of ZeroTier network IDs that the system should
        automatically join at boot.
      '';
    };
    mtu = lib.mkOption {
      type = lib.types.nullOr lib.types.int;
      default = null;
      example = 1280;
      description = "MTU to set on ZeroTier interfaces. Useful to prevent stalling on large transfers.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.zerotierone = {
      enable = true;
      joinNetworks = cfg.networks;
    };

    systemd.services.zerotierone = lib.mkIf (cfg.mtu != null) {
      postStart = ''
        sleep 5
        for iface in $(${lib.getExe' pkgs.iproute2 "ip"} link | grep zt | awk -F: '{print $2}' | tr -d ' '); do
          ip link set "$iface" mtu ${toString cfg.mtu}
        done
      '';
    };
  };
}