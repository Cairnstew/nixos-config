{ config, lib, pkgs, ... }:
let
  inherit (lib) mkIf;
  cfg = config.my.programs.houdini;
in
{
  # ── L0: Nix Assertions ────────────────────────────────────────────────────
  assertions = [
    {
      assertion = !cfg.enable || (cfg.licenseServer != null) ->
        builtins.match "^.+:[0-9]+$" cfg.licenseServer != null;
      message = ''
        `my.programs.houdini.licenseServer` must be in `host:port` format
        (e.g. `"license-server.local:1715"`) when set.
      '';
    }
  ];

  # ── L2: Smoke Test ────────────────────────────────────────────────────────
  systemd.services.houdini-smoke-test = mkIf cfg.enable {
    description = "Smoke test for Houdini installation";
    serviceConfig.Type = "oneshot";
    script = ''
      set -euo pipefail
      echo "=== Houdini Smoke Test ==="

      # Check binary exists
      if ! command -v houdini >/dev/null 2>&1; then
        echo "FAIL: houdini binary not found in PATH"
        exit 1
      fi
      echo "PASS: houdini binary found"

      # Check HFS environment
      if [ -z "''${HFS:-}" ]; then
        echo "FAIL: HFS environment variable not set"
        exit 1
      fi
      echo "PASS: HFS = $HFS"

      # Check hkey (license tool) exists
      if command -v hkey >/dev/null 2>&1; then
        echo "PASS: hkey (license tool) found"
      else
        echo "INFO: hkey not found (optional)"
      fi

      # Check hserver (license daemon) if no remote server
      if [ -z "''${sesi_license:-}" ]; then
        if command -v hserver >/dev/null 2>&1; then
          echo "PASS: hserver (license daemon) found"
        else
          echo "INFO: hserver not found (optional)"
        fi
      else
        echo "INFO: Using remote license server at $sesi_license"
      fi

      echo "=== Smoke Test Complete ==="
    '';
  };
}
