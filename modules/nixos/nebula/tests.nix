{ config, lib, pkgs, ... }:
let
  inherit (lib) mkIf;
  cfg = config.my.services.nebula;
  hostname = config.networking.hostName;
  hostCfg = cfg.hosts.${hostname} or null;
in
{
  # ── L0: Nix assertions ──────────────────────────────────────────────────────
  assertions = [
    # Host must have a config entry when nebula is enabled
    {
      assertion = !cfg.enable || hostCfg != null;
      message = ''
        Nebula VPN is enabled but no host configuration found for this host
        ("${hostname}"). Add an entry to `my.services.nebula.hosts.${hostname}`
        with at least `ip` and `cert` set.
      '';
    }

    # keyFile and keySecretFile are mutually exclusive
    {
      assertion = !cfg.enable || hostCfg == null ||
        (hostCfg.keyFile == null || hostCfg.keySecretFile == null);
      message = ''
        Nebula host "${hostname}" has both `keyFile` and `keySecretFile` set.
        These options are mutually exclusive. Use `keySecretFile` for
        agenix-managed keys or `keyFile` for manually-managed keys.
      '';
    }

    # Non-lighthouse hosts must have at least one lighthouse address
    {
      assertion = !cfg.enable || hostCfg == null ||
        hostCfg.isLighthouse || hostCfg.lighthouseAddrs != [ ];
      message = ''
        Nebula host "${hostname}" is not a lighthouse but has no
        lighthouse addresses configured. Set `lighthouseAddrs` to at
        least one lighthouse endpoint (e.g. `[ "10.10.0.1:4242" ]`).
      '';
    }

    # Listen port must be a valid UDP port
    {
      assertion = !cfg.enable || (cfg.listenPort > 0 && cfg.listenPort <= 65535);
      message = "Nebula listen port must be between 1 and 65535, got ${toString cfg.listenPort}.";
    }

    # DNS port must be valid when DNS is enabled
    {
      assertion = !cfg.enable || !cfg.dns.enable ||
        (cfg.dns.port > 0 && cfg.dns.port <= 65535);
      message = "Nebula DNS port must be between 1 and 65535, got ${toString cfg.dns.port}.";
    }

    # Lighthouse must have openFirewall enabled to accept peer connections
    {
      assertion = !cfg.enable || hostCfg == null ||
        !hostCfg.isLighthouse || hostCfg.openFirewall;
      message = ''
        Nebula host "${hostname}" is a lighthouse but `openFirewall` is
        disabled. Lighthouses must accept incoming connections; enable
        `openFirewall` or set it to the default (true).
      '';
    }
  ];

  # ── L2: Smoke test service ──────────────────────────────────────────────────
  systemd.services.nebula-smoke-test = mkIf (cfg.enable && hostCfg != null) {
    description = "Smoke test for Nebula mesh VPN configuration";
    # Run manually: systemctl start nebula-smoke-test

    serviceConfig.Type = "oneshot";

    script = ''
      set -euo pipefail
      echo "=== Nebula Smoke Test ==="

      # Check nebula binary exists
      if ! command -v nebula >/dev/null 2>&1; then
        echo "FAIL: nebula binary not found"
        exit 1
      fi
      echo "PASS: nebula binary found"

      # Check nebula service exists
      if ! systemctl list-unit-files | grep -q "nebula@"; then
        echo "FAIL: nebula systemd service not found"
        exit 1
      fi
      echo "PASS: nebula systemd service unit exists"

      # Check the host has an IP configured
      HOST_IP="${hostCfg.ip}"
      if [ -n "$HOST_IP" ]; then
        echo "PASS: host IP configured: $HOST_IP"
      else
        echo "FAIL: host IP not configured"
        exit 1
      fi

      # Check CA cert path is set
      CA_PATH="${cfg.ca}"
      if [ -n "$CA_PATH" ]; then
        echo "PASS: CA certificate path configured: $CA_PATH"
      else
        echo "FAIL: CA certificate path not configured"
        exit 1
      fi

      # Check cert path is set
      CERT_PATH="${hostCfg.cert}"
      if [ -n "$CERT_PATH" ]; then
        echo "PASS: host certificate path configured: $CERT_PATH"
      else
        echo "FAIL: host certificate path not configured"
        exit 1
      fi

      # Check key source
      if [ "${if hostCfg.keySecretFile != null then "true" else "false"}" = "true" ]; then
        echo "PASS: key sourced from agenix secret: ${hostCfg.keySecretFile}"
      else
        echo "PASS: key sourced from manual keyFile: ${hostCfg.keyFile}"
      fi

      # Verify lighthouse status
      if [ "${if hostCfg.isLighthouse then "true" else "false"}" = "true" ]; then
        echo "PASS: host is configured as lighthouse"
      else
        echo "PASS: host is configured as non-lighthouse peer"
        echo "INFO: lighthouse addresses: ${builtins.toString hostCfg.lighthouseAddrs}"
      fi

      echo "=== Nebula Smoke Test Complete ==="
    '';
  };
}
