{ config, lib, inputs, ... }:
{
  perSystem = { pkgs, system, ... }:
    let
      agenix = inputs.agenix.packages.${system}.default;

      secrets-validate = pkgs.writeShellApplication {
        name = "secrets-validate";
        runtimeInputs = with pkgs; [ jq findutils gnused coreutils ];
        text = ''
          set -euo pipefail

          FLAKE_ROOT="''${FLAKE_ROOT:-$PWD}"
          SECRETS_DIR="$FLAKE_ROOT/modules/nixos/secrets"
          MANIFEST="$SECRETS_DIR/secrets-manifest.json"
          EXIT_CODE=0

          echo "=== Secrets Validation ==="
          echo ""

          if [ ! -f "$MANIFEST" ]; then
            echo "ERROR: Manifest not found at $MANIFEST"
            exit 1
          fi

          echo "--- Check 1: Manifest entries → .age files ---"
          jq -r '.secrets[].name' "$MANIFEST" | while read -r name; do
            FILE="$SECRETS_DIR/$name.age"
            if [ -f "$FILE" ]; then
              echo "  OK: $name.age"
            else
              echo "  MISSING: $name.age (manifest entry but no file)"
              EXIT_CODE=1
            fi
          done

          echo ""
          echo "--- Check 2: .age files → manifest entries ---"
          find "$SECRETS_DIR" -maxdepth 1 -name '*.age' -not -path '*/\.*' -printf '%f\n' | sed 's/\.age$//' | while read -r name; do
            FOUND=$(jq -r --arg name "$name" '.secrets[] | select(.name == $name) | .name' "$MANIFEST")
            if [ -n "$FOUND" ]; then
              echo "  OK: $name.age → manifest"
            else
              echo "  ORPHAN: $name.age (not in manifest)"
            fi
          done

          echo ""
          if [ $EXIT_CODE -eq 0 ]; then
            echo "All checks passed."
          else
            echo "Some checks failed."
          fi
          exit $EXIT_CODE
        '';
      };

      secrets-set = pkgs.writeShellApplication {
        name = "secrets-set";
        runtimeInputs = [ agenix ] ++ (with pkgs; [ age jq coreutils ]);
        text = ''
          set -euo pipefail

          usage() {
            cat <<EOF
          Usage: secrets-set <name>

          Re-encrypt an existing secret with a new value read from stdin.
          The secret must have a manifest entry and .age file.

          Examples:
            echo -n "new-token" | secrets-set huggingface-token
            op read "op://Private/MySecret/credential" | secrets-set github-token

          Security:
            - Secret value is read ONLY from stdin (never from CLI args)
            - Temp files are securely deleted on exit
          EOF
          }

          if [ $# -eq 0 ] || [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
            usage
            exit 0
          fi

          NAME="$1"
          FLAKE_ROOT="''${FLAKE_ROOT:-$PWD}"
          SECRETS_DIR="$FLAKE_ROOT/modules/nixos/secrets"
          MANIFEST="$SECRETS_DIR/secrets-manifest.json"
          AGE_FILE="$SECRETS_DIR/$NAME.age"

          if [ ! -f "$MANIFEST" ]; then
            echo "ERROR: Manifest not found at $MANIFEST"
            exit 1
          fi

          if ! jq -e --arg name "$NAME" '.secrets[] | select(.name == $name)' "$MANIFEST" > /dev/null 2>&1; then
            echo "ERROR: '$NAME' not found in manifest."
            exit 1
          fi

          if [ ! -f "$AGE_FILE" ]; then
            echo "ERROR: $AGE_FILE does not exist."
            exit 1
          fi

          TMPFILE=$(mktemp)
          trap 'rm -f "$TMPFILE"' EXIT
          chmod 600 "$TMPFILE"
          cat > "$TMPFILE"

          if [ ! -s "$TMPFILE" ]; then
            echo "ERROR: empty secret value. Refusing to write."
            exit 1
          fi

          RECIPIENTS_FILE=$(mktemp)
          trap 'rm -f "$TMPFILE" "$RECIPIENTS_FILE"' EXIT

          jq -r '[.secrets[] | select(.name == "'"$NAME"'") | .scope] | .[0]' "$MANIFEST" > /dev/null
          echo "Reading recipients from agenix-manager cache at /etc/agenix/..."
          if [ -f /etc/agenix/keys-snapshot.json ]; then
            jq -r --arg name "$NAME" '.[$name] | .[]' /etc/agenix/keys-snapshot.json > "$RECIPIENTS_FILE"
          else
            echo "ERROR: No agenix-manager cache found at /etc/agenix/. Deploy first."
            exit 1
          fi

          if [ ! -s "$RECIPIENTS_FILE" ]; then
            echo "ERROR: could not extract public keys for '$NAME'"
            exit 1
          fi

          age -R "$RECIPIENTS_FILE" -o "$AGE_FILE" "$TMPFILE"

          : > "$TMPFILE"
          echo "Updated: $NAME.age"
        '';
      };

    in
    {
      devShells.secrets = pkgs.mkShell {
        name = "secrets";
        packages = with pkgs; [
          agenix
          _1password-cli
          jq
        ];

        shellHook = ''
          export EDITOR=''${EDITOR:-nano}

          echo ""
          echo "=== Secrets DevShell ==="
          echo "Available commands:"
          echo "  secrets-validate  → validate manifest vs .age files"
          echo "  secrets-set      → re-encrypt an existing secret from stdin"
          echo ""
          echo "Use 'agenix-manager' for TUI-based secret management."
          echo "Manually edit with: agenix -e modules/nixos/secrets/<name>.age"
          echo ""
        '';
      };

      packages = {
        inherit
          secrets-validate
          secrets-set;
      };

      apps = {
        secrets-validate = { type = "app"; program = "${secrets-validate}/bin/secrets-validate"; meta.description = "Validate manifest vs .age files in modules/nixos/secrets/"; };
        secrets-set = { type = "app"; program = "${secrets-set}/bin/secrets-set"; meta.description = "Re-encrypt an existing secret with a new value from stdin"; };
      };
    };
}
