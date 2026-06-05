{ config, lib, pkgs, ... }:
let
  secretNames = builtins.attrNames config.age.secrets;
in
{
  # ── L0: Nix assertions ──────────────────────────────────────────────────────
  assertions = [
    {
      assertion = secretNames != [ ];
      message = "No age.secrets declared. Ensure agenixManager is enabled and manifest is populated.";
    }
  ];

  # ── L1: Secret file existence checks (runtime) ─────────────────────────────
  systemd.services.secrets-validation = {
    description = "Validate agenix secrets exist and are readable";
    after = [ "agenix.service" ];
    requires = [ "agenix.service" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "secrets-validation" ''
        set -euo pipefail
        echo "=== Validating Secrets ==="

        ${lib.concatStringsSep "\n" (map (name: ''
          SECRET_PATH="${config.age.secrets.${name}.path}"
          if [ -f "$SECRET_PATH" ]; then
            if [ -r "$SECRET_PATH" ]; then
              echo "PASS: ${name} exists and is readable"
            else
              echo "FAIL: ${name} exists but is not readable"
              exit 1
            fi
          else
            echo "WARN: ${name} not yet decrypted (may be created on first deployment)"
          fi
        '') secretNames)}

        echo "=== Secrets Validation Complete ==="
      '';
    };
  };

  # ── L2: Smoke test service ─────────────────────────────────────────────────
  systemd.services.secrets-smoke-test = {
    description = "Smoke test for secrets configuration";
    # Not enabled by default - run manually: systemctl start secrets-smoke-test

    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "secrets-smoke-test" ''
        set -euo pipefail
        echo "=== Secrets Smoke Test ==="

        if ! command -v ${pkgs.age}/bin/age >/dev/null 2>&1; then
          echo "FAIL: age binary not found"
          exit 1
        fi
        echo "PASS: age binary found"

        if [ -f /run/agenix/ssh-key.pub ] || [ -d /run/agenix ]; then
          echo "PASS: age.secrets appears to be configured (agenix directory exists)"
        else
          echo "INFO: age.secrets may not be configured yet"
        fi

        ${lib.concatStringsSep "\n" (map (name: ''
          SECRET_NAME="${name}"
          SECRET_PATH="${config.age.secrets.${name}.path or "/dev/null"}"
          OWNER="${config.age.secrets.${name}.owner or "root"}"
          GROUP="${config.age.secrets.${name}.group or "root"}"

          echo "Checking secret: $SECRET_NAME"
          echo "  Expected path: $SECRET_PATH"
          echo "  Expected owner: $OWNER"
          echo "  Expected group: $GROUP"

          if [ -f "$SECRET_PATH" ]; then
            echo "  PASS: Secret file exists"
            FILE_OWNER=$(stat -c '%U' "$SECRET_PATH" 2>/dev/null || echo "unknown")
            FILE_GROUP=$(stat -c '%G' "$SECRET_PATH" 2>/dev/null || echo "unknown")
            echo "  Actual owner: $FILE_OWNER, group: $FILE_GROUP"
          else
            echo "  INFO: Secret file not yet present (will be created by agenix)"
          fi
        '') secretNames)}

        echo "=== Smoke Test Complete ==="
      '';
    };
  };
}
