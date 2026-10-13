{ config, lib, pkgs, ... }:
let
  inherit (lib) mkIf;
  cfg = config.my.programs.houdini;
in
{
  # ── L0: Nix Assertions ────────────────────────────────────────────────────
  assertions = [
    {
      # NOTE: `->` does NOT short-circuit here (both operands get evaluated
      # when the assertion list is forced), so guard the match on null first.
      assertion = cfg.licenseServer == null ||
        builtins.match "^.+:[0-9]+$" cfg.licenseServer != null;
      message = ''
        `my.programs.houdini.licenseServer` must be in `host:port` format
        (e.g. `"license-server.local:1715"`) when set.
      '';
    }
    {
      assertion = !cfg.localLicenseServer.enable || cfg.licenseServer == null;
      message = ''
        `my.programs.houdini.localLicenseServer.enable` and
        `my.programs.houdini.licenseServer` are mutually exclusive.
        Use one or the other, not both.
      '';
    }
    {
      assertion = !cfg.redeemNonCommercial.enable || cfg.redeemNonCommercial.serverCode != "";
      message = ''
        `my.programs.houdini.redeemNonCommercial.serverCode` must be set when
        `redeemNonCommercial.enable = true`. Obtain it by running:

            sesictrl print-server

        after sesinetd is running, then paste the value into your host config.
      '';
    }
    {
      assertion = !cfg.redeemNonCommercial.enable ||
        builtins.match "^[0-9]+\.[0-9]+$" cfg.redeemNonCommercial.version != null;
      message = ''
        `my.programs.houdini.redeemNonCommercial.version` must be in
        `major.minor` format (e.g. "22.0"), got
        "${cfg.redeemNonCommercial.version}".
      '';
    }
    {
      assertion = !cfg.labs.enable || cfg.enable;
      message = ''
        `my.programs.houdini.labs.enable` requires the module itself to be
        enabled (`my.programs.houdini.enable = true`).
      '';
    }
  ];

  # ── L2: Smoke Test ────────────────────────────────────────────────────────
  systemd.services.houdini-smoke-test = mkIf cfg.enable {
    description = "Smoke test for Houdini installation";
    serviceConfig.Type = "oneshot";
    # systemd units don't inherit the user's PATH; point at the package
    # directly (environment.systemPackages only affects login shells).
    path = [ cfg.package pkgs.coreutils ];
    environment = {
      HFS = "${cfg.package}";
    } // lib.optionalAttrs cfg.labs.enable {
      HOUDINI_PACKAGE_DIR = "${cfg.labs.package}";
    };
    script = ''
      set -euo pipefail
      echo "=== Houdini Smoke Test ==="

      # Check binary exists
      if ! command -v houdini >/dev/null 2>&1; then
        echo "FAIL: houdini binary not found in PATH"
        exit 1
      fi
      echo "PASS: houdini binary found ($(houdini --version))"

      # Check HFS environment
      if [ -z "''${HFS:-}" ]; then
        echo "FAIL: HFS environment variable not set"
        exit 1
      fi
      echo "PASS: HFS = $HFS"

      # SideFX Labs package: launcher layout (SideFXLabs22.0.json + dir).
      if [ -n "''${HOUDINI_PACKAGE_DIR:-}" ]; then
        if [ -f "$HOUDINI_PACKAGE_DIR/SideFXLabs22.0.json" ] && \
           [ -d "$HOUDINI_PACKAGE_DIR/SideFXLabs22.0" ] && \
           [ -d "$HOUDINI_PACKAGE_DIR/SideFXLabs22.0/toolbar" ]; then
          echo "PASS: SideFX Labs package found ($HOUDINI_PACKAGE_DIR)"
        else
          echo "FAIL: SideFX Labs enabled but package layout missing in $HOUDINI_PACKAGE_DIR"
          exit 1
        fi
      else
        echo "INFO: SideFX Labs not enabled (HOUDINI_PACKAGE_DIR unset)"
      fi

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
