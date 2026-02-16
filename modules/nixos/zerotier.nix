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
  };

  config = lib.mkIf cfg.enable {
    services.zerotierone = {
      enable = true;
      joinNetworks = cfg.networks;
    };
  };
}
