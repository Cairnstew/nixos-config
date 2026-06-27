{ config, lib, pkgs, ... }:
let
  cfg = config.my.services.zerotier;
in
{
  # ── L0: Nix assertions ──────────────────────────────────────────────────────
  # No hard assertion on networks being non-empty — ZeroTier can be pre-installed
  # and networks joined later via `zerotier-cli join <network-id>`.

  # ── L2: Smoke test service ─────────────────────────────────────────────────
  systemd.services.zerotier-smoke-test = lib.mkIf cfg.enable {
    description = "Smoke test for ZeroTier One connectivity";
    serviceConfig.Type = "oneshot";
    script = ''
      echo "=== ZeroTier Smoke Test ==="

      if ! command -v ${pkgs.zerotierone}/bin/zerotier-cli >/dev/null 2>&1; then
        echo "FAIL: zerotier-cli not found"
        exit 1
      fi
      echo "PASS: zerotier-cli found"

      if ! systemctl is-active --quiet zerotierone; then
        echo "FAIL: zerotierone service is not active"
        exit 1
      fi
      echo "PASS: zerotierone service is active"

      STATUS=$(${pkgs.zerotierone}/bin/zerotier-cli status 2>/dev/null || echo "unknown")
      echo "INFO: ZeroTier status: $STATUS"

      echo "=== Smoke Test Complete ==="
    '';
  };
}
