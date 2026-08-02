{ lib, ... }:
let
  inherit (lib) mkEnableOption mkOption types;
in
{
  options.my.services.torSsh = {
    enable = mkEnableOption "Tor onion-service SSH — last-resort access with zero inbound ports";

    onionPort = mkOption {
      type = types.port;
      default = 22022;
      description = "Port the onion service listens on (client connects with -p this).";
    };

    localPort = mkOption {
      type = types.port;
      default = 22;
      description = "Local SSH port the onion service forwards to.";
    };

    serviceName = mkOption {
      type = types.str;
      default = "ssh";
      description = "Onion service name (directory under /var/lib/tor/onion/).";
    };

    secretKey = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = ''
        Path to a persistent Tor v3 onion private key. When null, Tor generates
        a key on first start and persists it at
        /var/lib/tor/onion/<serviceName>/ (stable across reboots/rebuilds on
        persistent storage). Point this at an agenix secret for a
        guaranteed-fixed address.
      '';
    };

    authorizedClients = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = ''
        v3 client authorization public keys (format:
        descriptor:x25519:<base32-public-key>). Only listed clients can access
        the onion service. Empty list = open to anyone who learns the address.
      '';
    };

    openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = "Open firewall ports for Tor. Not needed for an onion service (outbound-only).";
    };
  };
}
