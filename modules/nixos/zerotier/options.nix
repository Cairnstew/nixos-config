{ lib, ... }:
let
  inherit (lib) mkEnableOption mkOption types;
in
{
  options.my.services.zerotier = {
    enable = mkEnableOption "ZeroTier One mesh VPN";

    networks = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [ "8056c2e21c000001" ];
      description = "ZeroTier network IDs to join on startup.";
    };

    localConf = mkOption {
      type = types.nullOr types.attrs;
      default = null;
      description = "Optional ZeroTier local.conf attrs (e.g. { settings.allowTcpFallbackRelay = false; }).";
    };

    openFirewall = mkOption {
      type = types.bool;
      default = true;
      description = "Open the ZeroTier port in the firewall.";
    };

    package = mkOption {
      type = types.nullOr types.package;
      default = null;
      description = "ZeroTierOne package to use. Defaults to pkgs.zerotierone.";
    };
  };
}
