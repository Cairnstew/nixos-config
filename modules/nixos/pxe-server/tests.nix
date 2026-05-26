{ config, lib, pkgs, ... }:
let
  inherit (lib) mkIf;
  cfg = config.my.services.pxeServer;
  isIp = ip: builtins.match "^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$" ip != null;
in
{
  # ── L0: Nix assertions ──────────────────────────────────────────────────────
  assertions = [
    {
      assertion = !cfg.enable || cfg.interface != "";
      message = "PXE server interface must not be empty";
    }
    {
      assertion = !cfg.enable || isIp cfg.serverIp;
      message = ''
        PXE server IP "${cfg.serverIp}" is not a valid IPv4 address.
        Must be in dotted-decimal format (e.g., 192.168.100.1).
      '';
    }
  ];

  # ── L2: Smoke test service ──────────────────────────────────────────────────
  systemd.services.pxe-server-smoke-test = mkIf cfg.enable {
    description = "Smoke test for PXE server configuration";
    serviceConfig.Type = "oneshot";
    script = ''
      set -euo pipefail
      echo "=== PXE Server Smoke Test ==="

      if ! command -v dnsmasq >/dev/null 2>&1; then
        echo "FAIL: dnsmasq binary not found"
        exit 1
      fi
      echo "PASS: dnsmasq binary found"

      if ! systemctl list-unit-files | grep -q "dnsmasq.service"; then
        echo "FAIL: dnsmasq.service not found"
        exit 1
      fi
      echo "PASS: dnsmasq.service exists"

      if ! systemctl list-unit-files | grep -q "nginx.service"; then
        echo "FAIL: nginx.service not found"
        exit 1
      fi
      echo "PASS: nginx.service exists"

      echo "INFO: Interface: ${cfg.interface}"
      echo "INFO: Server IP: ${cfg.serverIp}"
      echo "INFO: DHCP range: ${cfg.dhcpRange}"
      echo "INFO: Firewall TCP: 8080"
      echo "INFO: Firewall UDP: 67, 68, 69"

      if ! command -v ${pkgs.ipxe}/ipxe.efi >/dev/null 2>&1; then
        echo "WARN: ipxe.efi not directly accessible (will be copied at runtime)"
      else
        echo "PASS: ipxe.efi available"
      fi

      echo "=== PXE Server Smoke Test Complete ==="
    '';
  };
}
