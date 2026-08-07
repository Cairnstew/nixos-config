{ config, lib, ... }:

let
  inherit (lib) mkIf optional;

  cfg = config.my.services.nebula;

  # Auto-detect hostname from NixOS config
  hostname = config.networking.hostName;

  # Resolve the host config for this machine
  hostCfg = cfg.hosts.${hostname} or null;

  # Secret name for this host's key
  secretName = "nebula-${hostname}-key";

  # Resolved key path — prefer auto-managed secret over manual
  resolvedKeyFile =
    if hostCfg != null && hostCfg.keySecretFile != null
    then config.age.secrets.${secretName}.path
    else if hostCfg != null then hostCfg.keyFile
    else null;
in
{
  # ── Implementation ────────────────────────────────────────────────────────
  config = mkIf (cfg.enable && hostCfg != null) {

    # Auto-declare age.secrets for this host's key if keySecretFile is set.
    age.secrets.${secretName} = mkIf (hostCfg.keySecretFile != null) {
      file = hostCfg.keySecretFile;
      owner = "nebula-${cfg.network}";
      mode = "0400";
    };

    # Open firewall port if requested.
    networking.firewall.allowedUDPPorts =
      optional (hostCfg.openFirewall && hostCfg.isLighthouse) cfg.listenPort;

    services.nebula.networks.${cfg.network} = {
      enable = true;
      ca = cfg.ca;
      cert = hostCfg.cert;
      key = resolvedKeyFile;

      isLighthouse = hostCfg.isLighthouse;

      staticHostMap = mkIf (hostCfg.lighthouseAddrs != [ ]) (
        # Build staticHostMap from lighthouse nebula IPs
        # Users should set this explicitly if needed — placeholder here
        { }
      );

      lighthouses = mkIf (!hostCfg.isLighthouse && hostCfg.lighthouseAddrs != [ ])
        # Extract just the IPs from "ip:port" strings
        (map (addr: lib.head (lib.splitString ":" addr)) hostCfg.lighthouseAddrs);

      listen = {
        host = "0.0.0.0";
        port = cfg.listenPort;
      };

      dns = mkIf cfg.dns.enable {
        host = cfg.dns.host;
        port = cfg.dns.port;
      };

      firewall = {
        inbound = cfg.firewall.inbound;
        outbound = cfg.firewall.outbound;
      };
    };
  };
}
