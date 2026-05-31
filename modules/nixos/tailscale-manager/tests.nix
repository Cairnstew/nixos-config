{ config, lib, pkgs, ... }:
let
  cfg = config.my.services.tailscale-manager;
  sec = config.my.secrets;

  hasOauthSecret = sec.catalog."tailscale-manager.oauth".file or null != null;
in
{
  assertions = [
    {
      assertion = !(cfg.enable && sec.enable) || hasOauthSecret;
      message = ''
        Tailscale-manager requires "tailscale-manager.oauth" secret to be
        defined in my.secrets.catalog when secrets are enabled.
        Ensure the catalog entry exists under that logical path.
      '';
    }
    {
      assertion = !cfg.enable || cfg.tailnet != "";
      message = "tailnet must be set when tailscale-manager is enabled (use \"-\" for auto-resolve).";
    }
  ];

  systemd.services.tailscale-manager-smoke-test = lib.mkIf cfg.enable {
    description = "Smoke test for tailscale-manager configuration";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "tailscale-manager-smoke-test" ''
        set -euo pipefail
        echo "=== Tailscale Manager Smoke Test ==="

        if ! command -v ${pkgs.tailscale-manager or pkgs.tailscale-manager}/bin/tailscale-manager >/dev/null 2>&1; then
          echo "FAIL: tailscale-manager binary not found"
          exit 1
        fi
        echo "PASS: tailscale-manager binary found"

        STATE_DIR="${cfg.stateDir}"
        if [ -d "$STATE_DIR" ]; then
          echo "PASS: state directory $STATE_DIR exists"
        else
          echo "INFO: state directory $STATE_DIR does not exist yet (created on first apply)"
        fi

        echo "=== Smoke Test Complete ==="
      '';
    };
  };
}
