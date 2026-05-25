{ lib, ... }:
let
  inherit (lib) mkOption mkEnableOption types;
in
{
  options.my.programs.steam = {
    enable = mkEnableOption "Steam gaming platform with 32-bit support and gaming tools";

    remotePlay = {
      openFirewall = mkOption {
        type = types.bool;
        default = false;
        description = "Open firewall ports for Steam Remote Play Together.";
      };
    };

    dedicatedServer = {
      openFirewall = mkOption {
        type = types.bool;
        default = false;
        description = "Open firewall ports for Steam Dedicated Servers.";
      };
    };

    gamemode = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable Feral Gamemode for game performance optimizations.";
      };
    };

    extraCompatPaths = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''
        Extra compatibility tool paths for Steam Proton.
        Example: "$HOME/.steam/root/compatibilitytools.d"
      '';
    };

    extraPackages = mkOption {
      type = types.listOf types.package;
      default = [ ];
      description = "Extra Steam-related packages to install system-wide.";
    };
  };
}
