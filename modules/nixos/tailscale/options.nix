{ config, lib, ... }:
let
  inherit (lib) mkEnableOption mkOption types;
in
{
  options.my.services.tailscale = {
    enable = mkEnableOption "Tailscale mesh VPN";

    openFirewall = mkOption {
      type = types.bool;
      default = true;
      description = "Open the Tailscale UDP port in the firewall.";
    };

    exitNode = mkOption {
      type = types.bool;
      default = false;
      description = "Advertise this machine as a Tailscale exit node.";
    };

    tags = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [ "tag:nixos" "tag:personal" ];
      description = "Tailscale ACL tags to advertise for this machine.";
    };

    ssh = {
      enable = mkEnableOption "Static SSH config for tailnet machines";

      user = mkOption {
        type = types.str;
        description = "Local user whose SSH config will be managed.";
        example = "alice";
      };

      publicKeyPath = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Path to the Tailscale SSH public key to authorise on this host.";
      };

      extraHostConfig = mkOption {
        type = types.lines;
        default = "";
        description = "Extra lines appended inside every generated Host block (e.g. 'ForwardAgent yes').";
        example = "ForwardAgent yes\nServerAliveInterval 60";
      };
    };
  };
}
