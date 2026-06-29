{ config, lib, pkgs, ... }:
let
  cfg = config.my.services.tailscale;
in
{
  # ── L0: Nix assertions ──────────────────────────────────────────────────────
  assertions = [
    {
      assertion = !(cfg.enable && cfg.exitNode) ||
        (cfg.tags != [ ]);
      message = "Tailscale exit nodes should have at least one tag in tags.";
    }
    {
      assertion = !cfg.enable || !cfg.ssh.enable ||
        (cfg.ssh.user != "");
      message = "Tailscale SSH config requires a user to be set when ssh.enable is true.";
    }

  ];

  # ── L1: systemd service health checks ─────────────────────────────────────
  systemd.services.tailscale-health-check = lib.mkIf cfg.enable {
    description = "Health check for tailscale connectivity";
    after = [ "tailscaled.service" "network-online.target" ];
    requires = [ "tailscaled.service" "network-online.target" ];
    # Don't block boot — this is informational-only and tailscale may not
    # be authenticated yet (especially in VMs or first-boot scenarios).

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "tailscale-health-check" ''
        set -euo pipefail
        TIMEOUT=60
        ELAPSED=0

        echo "Checking tailscale status..."

        while [ $ELAPSED -lt $TIMEOUT ]; do
          if ${pkgs.tailscale}/bin/tailscale status --json 2>/dev/null | ${pkgs.jq}/bin/jq -e '.BackendState == "Running"' >/dev/null 2>&1; then
            echo "Tailscale is Running"
            exit 0
          fi
          sleep 2
          ELAPSED=$((ELAPSED + 2))
        done

        echo "WARNING: Tailscale did not reach Running state within $TIMEOUT seconds"
        exit 0  # Don't fail boot, just warn
      '';
    };
  };

  # ── L2: Smoke test service ─────────────────────────────────────────────────
  systemd.services.tailscale-smoke-test = lib.mkIf cfg.enable {
    description = "Smoke test for tailscale configuration";
    # Not enabled by default - run manually: systemctl start tailscale-smoke-test

    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "tailscale-smoke-test" ''
        set -euo pipefail
        echo "=== Tailscale Smoke Test ==="

        # Check tailscale binary exists
        if ! command -v ${pkgs.tailscale}/bin/tailscale >/dev/null 2>&1; then
          echo "FAIL: tailscale binary not found"
          exit 1
        fi
        echo "PASS: tailscale binary found"

        # Check tailscaled service is active
        if ! systemctl is-active --quiet tailscaled; then
          echo "FAIL: tailscaled service is not active"
          exit 1
        fi
        echo "PASS: tailscaled service is active"

        # Check tailscale interface exists
        if ! ip link show tailscale0 >/dev/null 2>&1; then
          echo "FAIL: tailscale0 interface not found"
          exit 1
        fi
        echo "PASS: tailscale0 interface exists"

        # Check if we're logged in
        STATUS=$(${pkgs.tailscale}/bin/tailscale status --json 2>/dev/null | ${pkgs.jq}/bin/jq -r '.BackendState // "unknown"')
        echo "INFO: Tailscale state: $STATUS"

        if [ "$STATUS" = "Running" ]; then
          IP=$(${pkgs.tailscale}/bin/tailscale ip -4 2>/dev/null || echo "unknown")
          echo "PASS: Tailscale is Running (IP: $IP)"
        else
          echo "WARNING: Tailscale state is $STATUS (expected: Running)"
        fi

        ${lib.optionalString cfg.ssh.enable ''
        # Check SSH config exists
        SSH_CONFIG="/home/${cfg.ssh.user}/.ssh/config.d/tailscale"
        if [ -f "$SSH_CONFIG" ]; then
          echo "PASS: SSH config file exists at $SSH_CONFIG"
        else
          echo "FAIL: SSH config file not found at $SSH_CONFIG"
          exit 1
        fi
        ''}

        echo "=== Smoke Test Complete ==="
      '';
    };
  };
}
