{ config, lib, pkgs, ... }:

let
  inherit (lib)
    mkEnableOption mkOption mkIf mkDefault types literalExpression
    mapAttrs' nameValuePair optional optionalAttrs;

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

  # Per-host submodule
  hostOpts = { name, ... }: {
    options = {
      ip = mkOption {
        type = types.str;
        description = "Nebula IP with CIDR for this host (e.g. 10.10.0.1/24).";
        example = "10.10.0.1/24";
      };

      isLighthouse = mkOption {
        type = types.bool;
        default = false;
        description = "Whether this host acts as a Nebula lighthouse.";
      };

      cert = mkOption {
        type = types.path;
        description = "Path to the host's Nebula certificate (.crt).";
        example = literalExpression "flake.inputs.self + /certs/server.crt";
      };

      keySecretFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = ''
          Path to the agenix-encrypted .age file for this host's Nebula
          private key. The module declares age.secrets automatically.
          Use this OR keyFile, not both.
        '';
        example = literalExpression "flake.inputs.self + /secrets/nebula-server.key.age";
      };

      keyFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = ''
          Path to the decrypted Nebula private key at runtime.
          Use this if you manage age.secrets yourself.
          Use this OR keySecretFile, not both.
        '';
      };

      lighthouseAddrs = mkOption {
        type = types.listOf types.str;
        default = [];
        description = ''
          Static addresses of lighthouse nodes in host:port format.
          Leave empty on the lighthouse itself.
        '';
        example = [ "1.2.3.4:4242" ];
      };

      openFirewall = mkOption {
        type = types.bool;
        default = true;
        description = "Open the Nebula listen port in the firewall.";
      };
    };
  };

in
{
  # ── Options ──────────────────────────────────────────────────────────────
  options.my.services.nebula = {
    enable = mkEnableOption "Nebula mesh VPN";

    network = mkOption {
      type = types.str;
      default = "homelab";
      description = "Nebula network name (used as the systemd service suffix).";
    };

    ca = mkOption {
      type = types.path;
      description = "Path to the Nebula CA certificate (ca.crt). Safe to commit plaintext.";
      example = literalExpression "flake.inputs.self + /certs/ca.crt";
    };

    listenPort = mkOption {
      type = types.int;
      default = 4242;
      description = "UDP port Nebula listens on.";
    };

    hosts = mkOption {
      type = types.attrsOf (types.submodule hostOpts);
      default = {};
      description = ''
        Per-host Nebula configuration keyed by hostname.
        The module auto-detects config.networking.hostName and applies
        the matching entry automatically.
      '';
      example = literalExpression ''
        {
          server = {
            ip           = "10.10.0.1/24";
            isLighthouse = true;
            cert         = flake.inputs.self + /certs/server.crt;
            keySecretFile = flake.inputs.self + /secrets/nebula-server.key.age;
          };
          laptop = {
            ip              = "10.10.0.2/24";
            cert            = flake.inputs.self + /certs/laptop.crt;
            keySecretFile   = flake.inputs.self + /secrets/nebula-laptop.key.age;
            lighthouseAddrs = [ "1.2.3.4:4242" ];
          };
          wsl = {
            ip              = "10.10.0.3/24";
            cert            = flake.inputs.self + /certs/wsl.crt;
            keySecretFile   = flake.inputs.self + /secrets/nebula-wsl.key.age;
            lighthouseAddrs = [ "1.2.3.4:4242" ];
          };
        }
      '';
    };

    dns = {
      enable = mkEnableOption "Nebula built-in DNS (requires nebula >= 1.6)";
      host = mkOption {
        type = types.str;
        default = "0.0.0.0";
        description = "Interface to bind the Nebula DNS listener.";
      };
      port = mkOption {
        type = types.int;
        default = 53;
        description = "Port for the Nebula DNS listener.";
      };
    };

    firewall = {
      inbound = mkOption {
        type = types.listOf types.attrs;
        default = [{ port = "any"; proto = "any"; host = "any"; }];
        description = "Nebula inbound firewall rules.";
      };
      outbound = mkOption {
        type = types.listOf types.attrs;
        default = [{ port = "any"; proto = "any"; host = "any"; }];
        description = "Nebula outbound firewall rules.";
      };
    };
  };

  # ── Implementation ────────────────────────────────────────────────────────
  config = mkIf (cfg.enable && hostCfg != null) {

    # Auto-declare age.secrets for this host's key if keySecretFile is set.
    age.secrets.${secretName} = mkIf (hostCfg.keySecretFile != null) {
      file  = hostCfg.keySecretFile;
      owner = "nebula-${cfg.network}";
      mode  = "0400";
    };

    # Open firewall port if requested.
    networking.firewall.allowedUDPPorts =
      optional (hostCfg.openFirewall && hostCfg.isLighthouse) cfg.listenPort;

    services.nebula.networks.${cfg.network} = {
      enable = true;
      ca     = cfg.ca;
      cert   = hostCfg.cert;
      key    = resolvedKeyFile;

      isLighthouse = hostCfg.isLighthouse;

      staticHostMap = mkIf (hostCfg.lighthouseAddrs != []) (
        # Build staticHostMap from lighthouse nebula IPs
        # Users should set this explicitly if needed — placeholder here
        {}
      );

      lighthouses = mkIf (!hostCfg.isLighthouse && hostCfg.lighthouseAddrs != [])
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
        inbound  = cfg.firewall.inbound;
        outbound = cfg.firewall.outbound;
      };
    };
  };
}
