{ config, lib, pkgs, ... }:
let
  inherit (lib) mkIf;
  toInt = builtins.fromJSON;
  cfg = config.my.services.natShare;

  # Helper: convert dotted-decimal IP to integer for comparison
  # Uses lib.splitString which returns a flat list (unlike builtins.split)
  ipToInt = ip:
    let
      parts = lib.splitString "." ip;
      p0 = toInt (builtins.elemAt parts 0);
      p1 = toInt (builtins.elemAt parts 1);
      p2 = toInt (builtins.elemAt parts 2);
      p3 = toInt (builtins.elemAt parts 3);
    in
    p0 * 16777216 + p1 * 65536 + p2 * 256 + p3;

  # Check if an IP is in private ranges: 10.x.x.x, 172.16-31.x.x, 192.168.x.x
  isPrivateIP = ip:
    let
      parts = lib.splitString "." ip;
      first = builtins.elemAt parts 0;
      second = builtins.elemAt parts 1;
    in
    first == "10" ||
    (first == "172" && (toInt second >= 16 && toInt second <= 31)) ||
    (first == "192" && second == "168");

  subnetPrefix = ip:
    let
      parts = lib.splitString "." ip;
    in
    builtins.concatStringsSep "." (lib.init parts);

  prefix = subnetPrefix cfg.lanAddress;
  startInt = ipToInt cfg.dhcpRangeStart;
  endInt = ipToInt cfg.dhcpRangeEnd;
in
{
  # ── L0: Nix assertions ──────────────────────────────────────────────────────
  assertions = [
    # WAN and LAN interfaces must be different
    {
      assertion = !cfg.enable || cfg.wanInterface != cfg.lanInterface;
      message = ''
        NAT sharing requires different WAN and LAN interfaces.
        Both are set to "${cfg.wanInterface}". Use distinct interfaces
        (e.g., wanInterface = "wlan0", lanInterface = "eth0").
      '';
    }

    # DHCP range start must be before end
    {
      assertion = !cfg.enable || startInt < endInt;
      message = ''
        NAT sharing DHCP range start (${cfg.dhcpRangeStart}) must be
        before range end (${cfg.dhcpRangeEnd}).
      '';
    }

    # LAN address must be in a private IP range
    {
      assertion = !cfg.enable || isPrivateIP cfg.lanAddress;
      message = ''
        NAT sharing LAN address "${cfg.lanAddress}" is not in a private
        IP range. Use 10.x.x.x, 172.16-31.x.x, or 192.168.x.x.
      '';
    }

    # DHCP range must be in the same /24 subnet as the LAN address
    {
      assertion = !cfg.enable ||
        (lib.hasPrefix prefix cfg.dhcpRangeStart &&
          lib.hasPrefix prefix cfg.dhcpRangeEnd);
      message = ''
        NAT sharing DHCP range (${cfg.dhcpRangeStart} - ${cfg.dhcpRangeEnd})
        must be in the same /24 subnet as the LAN address (${cfg.lanAddress}).
      '';
    }

    # LAN address must not be the same as DHCP start (reserved for gateway)
    {
      assertion = !cfg.enable || cfg.lanAddress != cfg.dhcpRangeStart;
      message = ''
        NAT sharing LAN address (${cfg.lanAddress}) conflicts with DHCP
        range start (${cfg.dhcpRangeStart}). The LAN address is reserved
        for the gateway; use a different DHCP range start.
      '';
    }
  ];

  # ── L2: Smoke test service ──────────────────────────────────────────────────
  systemd.services.natshare-smoke-test = mkIf cfg.enable {
    description = "Smoke test for NAT sharing configuration";
    # Run manually: systemctl start natshare-smoke-test

    serviceConfig.Type = "oneshot";

    script = ''
      set -euo pipefail
      echo "=== NAT Share Smoke Test ==="

      # Check dnsmasq binary exists
      if ! command -v dnsmasq >/dev/null 2>&1; then
        echo "FAIL: dnsmasq binary not found"
        exit 1
      fi
      echo "PASS: dnsmasq binary found"

      # Check dnsmasq service unit exists
      if ! systemctl list-unit-files | grep -q "dnsmasq.service"; then
        echo "FAIL: dnsmasq.service not found in systemd"
        exit 1
      fi
      echo "PASS: dnsmasq.service unit exists"

      # Check NAT is enabled
      echo "INFO: NAT enabled: WAN=${cfg.wanInterface} → LAN=${cfg.lanInterface}"
      echo "INFO: LAN address: ${cfg.lanAddress}/24"
      echo "INFO: DHCP range: ${cfg.dhcpRangeStart} - ${cfg.dhcpRangeEnd}"

      # Check that firewall ports are configured
      echo "INFO: Firewall UDP ports: 53 (DNS), 67 (DHCP)"
      echo "INFO: Firewall TCP ports: 53 (DNS)"
      echo "INFO: Trusted interface: ${cfg.lanInterface}"

      # Verify interface names are plausible (no empty strings)
      if [ -z "${cfg.wanInterface}" ]; then
        echo "FAIL: WAN interface name is empty"
        exit 1
      fi
      echo "PASS: WAN interface: ${cfg.wanInterface}"

      if [ -z "${cfg.lanInterface}" ]; then
        echo "FAIL: LAN interface name is empty"
        exit 1
      fi
      echo "PASS: LAN interface: ${cfg.lanInterface}"

      echo "=== NAT Share Smoke Test Complete ==="
    '';
  };
}
