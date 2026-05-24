{ config, lib, pkgs, ... }:
let
  cfg = config.my.secrets;

  # Get all secret names from the catalog
  secretNames = lib.attrNames cfg.catalog;

  # Check for duplicate secret names (same name, different paths)
  nameCounts = lib.foldl'
    (acc: name:
      let count = acc.${name} or 0;
      in acc // { ${name} = count + 1; }
    )
    { }
    (lib.catAttrs "name" (lib.attrValues cfg.catalog));

  duplicateNames = lib.filter (n: nameCounts.${n} > 1) (lib.attrNames nameCounts);
in
{
  # ── L0: Nix assertions ──────────────────────────────────────────────────────
  assertions = lib.mkIf cfg.enable [
    {
      assertion = cfg.catalog != { };
      message = "my.secrets.catalog must contain at least one secret definition when enabled.";
    }
    {
      assertion = duplicateNames == [ ];
      message = "Duplicate secret names in my.secrets.catalog: ${lib.concatStringsSep ", " duplicateNames}";
    }
    {
      assertion = lib.all (n: cfg.catalog.${n}.name != "") secretNames;
      message = "All secrets in my.secrets.catalog must have a non-empty name.";
    }
  ];

  # ── L1: Secret file existence checks (runtime) ─────────────────────────────
  # These run as systemd oneshot services to validate secrets exist

  systemd.services.secrets-validation = lib.mkIf cfg.enable {
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

        ${lib.concatStringsSep "\n" (lib.mapAttrsToList (path: secretDef: ''
          SECRET_PATH="${config.age.secrets.${secretDef.name}.path}"
          if [ -f "$SECRET_PATH" ]; then
            if [ -r "$SECRET_PATH" ]; then
              echo "PASS: ${secretDef.name} exists and is readable"
            else
              echo "FAIL: ${secretDef.name} exists but is not readable"
              exit 1
            fi
          else
            echo "WARN: ${secretDef.name} not yet decrypted (may be created on first deployment)"
          fi
        '') cfg.catalog)}

        echo "=== Secrets Validation Complete ==="
      '';
    };
  };

  # ── L2: Smoke test service ─────────────────────────────────────────────────
  systemd.services.secrets-smoke-test = lib.mkIf cfg.enable {
    description = "Smoke test for secrets configuration";
    # Not enabled by default - run manually: systemctl start secrets-smoke-test

    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "secrets-smoke-test" ''
        set -euo pipefail
        echo "=== Secrets Smoke Test ==="

        # Check age is installed (agenix dependency)
        if ! command -v ${pkgs.age}/bin/age >/dev/null 2>&1; then
          echo "FAIL: age binary not found"
          exit 1
        fi
        echo "PASS: age binary found"

        # Check age module is loaded (age.secrets exists)
        # We check if agenix identities file exists as a proxy for age.secrets being configured
        if [ -f /run/agenix/ssh-key.pub ] || [ -d /run/agenix ]; then
          echo "PASS: age.secrets appears to be configured (agenix directory exists)"
        else
          echo "INFO: age.secrets may not be configured yet"
        fi

        # Check each secret in catalog
        ${lib.concatStringsSep "\n" (lib.mapAttrsToList (path: secretDef: ''
          SECRET_NAME="${secretDef.name}"
          SECRET_PATH="${config.age.secrets.${secretDef.name}.path or "/dev/null"}"
          OWNER="${config.age.secrets.${secretDef.name}.owner or "root"}"
          GROUP="${config.age.secrets.${secretDef.name}.group or "root"}"

          echo "Checking secret: $SECRET_NAME"
          echo "  Expected path: $SECRET_PATH"
          echo "  Expected owner: $OWNER"
          echo "  Expected group: $GROUP"

          if [ -f "$SECRET_PATH" ]; then
            echo "  PASS: Secret file exists"
            # Check ownership if file exists
            FILE_OWNER=$(stat -c '%U' "$SECRET_PATH" 2>/dev/null || echo "unknown")
            FILE_GROUP=$(stat -c '%G' "$SECRET_PATH" 2>/dev/null || echo "unknown")
            echo "  Actual owner: $FILE_OWNER, group: $FILE_GROUP"
          else
            echo "  INFO: Secret file not yet present (will be created by agenix)"
          fi
        '') cfg.catalog)}

        echo "=== Smoke Test Complete ==="
      '';
    };
  };
}
