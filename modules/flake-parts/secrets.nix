# modules/flake-parts/secrets.nix
# Secrets management CLI — devShell + packages for secret lifecycle
{ config, lib, inputs, ... }:
let
  # The repo root, relative to this file (modules/flake-parts/secrets.nix → ./../..)
  root = ../..;

  # Minimal flake-like object for catalog evaluation
  flakeMock = {
    inputs = { self = root; };
    config = { me = config.me; };
  };

  # Import catalog to bake data into scripts
  catalog = (import ../nixos/secrets/catalog.nix { flake = flakeMock; inherit lib; }).secretsCatalog;

  # Build list of non-null-file entries for generation
  catalogEntries = lib.filter (e: e.fileRel != null) (lib.mapAttrsToList (name: def: {
    logicalPath = name;
    secretName = def.name;
    fileRel = def.fileRel;
    owner = def.owner or "root";
    group = def.group or "root";
    mode = def.mode or "0400";
  }) catalog);

  # Also collect entries with null files for warnings
  catalogNullEntries = lib.filter (e: e.fileRel == null) (lib.mapAttrsToList (name: def: {
    logicalPath = name;
    secretName = def.name;
    fileRel = def.fileRel;
  }) catalog);

  catalogJson = builtins.toJSON catalogEntries;
  catalogNullJson = builtins.toJSON catalogNullEntries;
in
{
  perSystem = { pkgs, system, ... }:
    let
      agenix = inputs.agenix.packages.${system}.default;

      # Write catalog JSON to files referenced at script runtime
      catalogJsonFile = pkgs.writeText "secrets-catalog.json" catalogJson;
      catalogNullJsonFile = pkgs.writeText "secrets-null-catalog.json" catalogNullJson;

      secrets-generate = pkgs.writeShellApplication {
        name = "secrets-generate";
        runtimeInputs = with pkgs; [ nixpkgs-fmt jq gnused gnugrep coreutils ];
        text = ''
          CATALOG_JSON='${catalogJsonFile}'
          CATALOG_NULL_JSON='${catalogNullJsonFile}'

          set -euo pipefail

          usage() {
            cat <<EOF
          Usage: secrets-generate [OPTIONS]

          Regenerate secrets/secrets.nix from the catalog.

          Options:
            --write       Write directly to secrets/secrets.nix (requires FLAKE_ROOT or PWD)
            --check       Check if regeneration would change the file (exit 1 if dirty)
            --help, -h    Show this help

          Default: output to stdout
          EOF
          }

          FLAKE_ROOT="''${FLAKE_ROOT:-$PWD}"
          WRITE=false
          CHECK=false

          while [ $# -gt 0 ]; do
            case "$1" in
              --write) WRITE=true; shift ;;
              --check) CHECK=true; shift ;;
              --help|-h) usage; exit 0 ;;
              *) echo "Unknown arg: $1"; usage; exit 1 ;;
            esac
          done

          SECRETS_FILE="$FLAKE_ROOT/secrets/secrets.nix"
          if [ ! -f "$SECRETS_FILE" ]; then
            echo "ERROR: $SECRETS_FILE not found. Run from repo root or set FLAKE_ROOT."
            exit 1
          fi

          # Extract the let-block: everything from start up to and including the last
          # let assignment (a line starting with non-whitespace non-comment before in {)
          # This matches everything before `in` on its own line
          LET_BLOCK=$(sed -n '1,/^in$/p' "$SECRETS_FILE" | head -n -1)
          if [ -z "$LET_BLOCK" ]; then
            echo "ERROR: Could not find let-block in $SECRETS_FILE"
            exit 1
          fi

          # Also capture the rest of the file after `in` to delete it
          # (the `{` after `in` might be on the same or next line)

          # Generate the attrset from catalog JSON
          ENTRIES=$(cat "''${CATALOG_JSON}" | jq -r '.[] | select(.fileRel != null) | "  \"\(.fileRel | ltrimstr("/secrets/"))\".publicKeys = all;"' | sort)
          NULL_ENTRIES=$(cat "''${CATALOG_NULL_JSON}" | jq -r '.[] | "  # \(.logicalPath) → \(.secretName) (file not yet created)"' | sort)

          # Build the generated file
          OUTPUT="$LET_BLOCK
          in
          {
          $ENTRIES

          $NULL_ENTRIES
          }"

          # Format
          FORMATTED=$(echo "$OUTPUT" | nixpkgs-fmt 2>/dev/null || echo "$OUTPUT")

          if [ "$CHECK" = true ]; then
            DIFF=$(diff -u "$SECRETS_FILE" <(echo "$FORMATTED") 2>/dev/null || true)
            if [ -n "$DIFF" ]; then
              echo "secrets/secrets.nix is out of sync with catalog. Run: secrets-generate --write"
              echo "$DIFF"
              exit 1
            fi
            echo "secrets/secrets.nix is up to date."
            exit 0
          fi

          if [ "$WRITE" = true ]; then
            echo "$FORMATTED" > "$SECRETS_FILE"
            echo "Wrote $SECRETS_FILE"
          else
            echo "$FORMATTED"
          fi
        '';
      };

      secrets-edit = pkgs.writeShellApplication {
        name = "secrets-edit";
        runtimeInputs = [ agenix ];
        text = ''
          set -euo pipefail

          usage() {
            cat <<EOF
          Usage: secrets-edit <relative-age-file>

          Create or edit an encrypted .age file.
          Opens \$EDITOR (default: nano) with the decrypted content.

          The path is relative to the secrets/ directory.
          Examples:
            secrets-edit ai/my-new-token.age
            secrets-edit tailscale/tailscale-oauthkey.age
          EOF
          }

          if [ $# -eq 0 ] || [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
            usage
            exit 0
          fi

          FILE="''${1#./}"  # strip leading ./
          SECRETS_DIR="./secrets"

          mkdir -p "$SECRETS_DIR/$(dirname "$FILE")"

          echo "Opening $SECRETS_DIR/$FILE for editing..."
          cd "$SECRETS_DIR" && exec agenix -e "$FILE"
        '';
      };

      secrets-rekey = pkgs.writeShellApplication {
        name = "secrets-rekey";
        runtimeInputs = [ agenix ] ++ (with pkgs; [ _1password-cli gnugrep gnused ]);
        text = ''
          set -euo pipefail

          echo "=== Rekeying all secrets from 1Password ==="

          if ! op account list &>/dev/null || [ -z "$(op account list)" ]; then
            echo "No 1Password accounts configured. Run: op account add"
            exit 1
          fi

          if ! op account get &>/dev/null; then
            eval "$(op signin)"
          fi

          TMPKEY=$(mktemp)
          trap 'rm -f $TMPKEY' EXIT

          echo "Reading private key from 1Password..."
          op read "op://Private/Nixos/private key" > "$TMPKEY"
          chmod 600 "$TMPKEY"

          echo "Rekeying all secrets..."
          exec agenix -r -i "$TMPKEY"
        '';
      };

      secrets-validate = pkgs.writeShellApplication {
        name = "secrets-validate";
        runtimeInputs = with pkgs; [ jq findutils gnused coreutils ];
        text = ''
          CATALOG_JSON='${catalogJsonFile}'
          SECRETS_GENERATE='${secrets-generate}/bin/secrets-generate'

          set -euo pipefail

          FLAKE_ROOT="''${FLAKE_ROOT:-$PWD}"
          EXIT_CODE=0

          echo "=== Secrets Validation ==="

          # Check 1: Every catalog entry with fileRel has a .age file
          echo "--- Check 1: Catalog entries → .age files ---"
          cat "$CATALOG_JSON" | jq -r '.[].fileRel | ltrimstr("/secrets/")' | while read -r rel; do
            FILE="$FLAKE_ROOT/secrets/$rel"
            if [ -f "$FILE" ]; then
              echo "  OK: $rel"
            else
              echo "  MISSING: $rel"
              EXIT_CODE=1
            fi
          done

          # Check 2: Every .age file has a catalog entry
          echo "--- Check 2: .age files → catalog entries ---"
          find "$FLAKE_ROOT/secrets" -name '*.age' -not -path '*/\.*' -printf '%P\n' | while IFS= read -r rel; do
            FOUND=$(cat "$CATALOG_JSON" | jq -r --arg rel "/secrets/$rel" '.[] | select(.fileRel == $rel) | .logicalPath')
            if [ -n "$FOUND" ]; then
              echo "  OK: $rel → $FOUND"
            else
              echo "  ORPHAN: $rel (not in catalog)"
            fi
          done

          # Check 3: Verify secrets-generate --check
          echo "--- Check 3: secrets/secrets.nix in sync ---"
          if ! "$SECRETS_GENERATE" --check 2>&1; then
            EXIT_CODE=1
          fi

          echo ""
          if [ $EXIT_CODE -eq 0 ]; then
            echo "All checks passed."
          else
            echo "Some checks failed."
          fi
          exit $EXIT_CODE
        '';
      };

      secrets-new = pkgs.writeShellApplication {
        name = "secrets-new";
        runtimeInputs = [ agenix ] ++ (with pkgs; [ jq gnused gnugrep coreutils nixpkgs-fmt ]);
        text = ''
          CATALOG_JSON='${catalogJsonFile}'

          set -euo pipefail
          set -euo pipefail

          usage() {
            cat <<EOF
          Usage: secrets-new <logical-path> [--owner <user>] [--group <group>] [--mode <mode>]

          Create a new secret end-to-end:
            1. Creates the encrypted .age file (opens \$EDITOR)
            2. Adds the catalog entry
            3. Outputs instructions for consumption

          Arguments:
            logical-path    Dotted path like "ai.myNewToken" or "github.mySecret"
            --owner <user>  Owner of decrypted file (default: seanc)
            --group <group> Group of decrypted file (default: root)
            --mode <mode>   Permissions (default: 0400)

          Examples:
            secrets-new ai.myNewToken --owner seanc
            secrets-new github.deployKey --owner root --mode 0600
          EOF
          }

          if [ $# -eq 0 ] || [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
            usage
            exit 0
          fi

          LOGICAL_PATH="$1"
          shift
          OWNER="seanc"
          GROUP="root"
          MODE="0400"

          while [ $# -gt 0 ]; do
            case "$1" in
              --owner) OWNER="$2"; shift 2 ;;
              --group) GROUP="$2"; shift 2 ;;
              --mode)  MODE="$2"; shift 2 ;;
              *) echo "Unknown arg: $1"; usage; exit 1 ;;
            esac
          done

          FLAKE_ROOT="''${FLAKE_ROOT:-$PWD}"
          CATALOG_FILE="$FLAKE_ROOT/modules/nixos/secrets/catalog.nix"

          # Validate: check catalog doesn't already have this path
          if cat "$CATALOG_JSON" | jq -e --arg path "$LOGICAL_PATH" '.[] | select(.logicalPath == $path)' > /dev/null 2>&1; then
            echo "ERROR: '$LOGICAL_PATH' already exists in the catalog!"
            exit 1
          fi

          # Derive fileRel from logical path: dots → /, last segment is filename
          # ai.myNewToken → ai/my-new-token.age
          DIR_PART=$(echo "$LOGICAL_PATH" | sed 's/\.[^.]*$//' | tr '.' '/')
          BASE_PART=$(echo "$LOGICAL_PATH" | sed 's/.*\.//' | sed 's/\([a-z]\)\([A-Z]\)/\1-\2/g' | tr '[:upper:]' '[:lower:]')
          FILE_REL="/$DIR_PART/$BASE_PART.age"

          echo "=== Creating new secret: $LOGICAL_PATH ==="
          echo ""
          echo "  File:   secrets$FILE_REL"
          echo "  Owner:  $OWNER"
          echo "  Group:  $GROUP"
          echo "  Mode:   $MODE"
          echo ""
          echo "Opening editor to enter the secret value..."
          mkdir -p "$FLAKE_ROOT/secrets/$DIR_PART"
          cd "$FLAKE_ROOT/secrets" && agenix -e "''${FILE_REL#/}"

          echo "Secret encrypted. Add this to $CATALOG_FILE:"
          echo ""
          echo "    \"$LOGICAL_PATH\" = secret \"$FILE_REL\" { owner = \"$OWNER\"; group = \"$GROUP\"; mode = \"$MODE\"; };"
          echo ""
          echo "Then run: nix run .#secrets-generate -- --write"
          echo ""
          echo "Consume in a module:"
          SECRET_NAME=$(echo "$FILE_REL" | sed 's|.*/||; s|\.age$||')
          echo "  config.age.secrets.\"$SECRET_NAME\".path"
        '';
      };
    in
    {
      devShells.secrets = pkgs.mkShell {
        name = "secrets";
        packages = [ agenix ] ++ (with pkgs; [
          _1password-cli
          jq
          nixpkgs-fmt
        ]);

        AGENIX_RULES = toString ./../../secrets/secrets.nix;

        shellHook = ''
          export EDITOR=''${EDITOR:-nano}
          export PRIVATE_KEY=''${PRIVATE_KEY:-/etc/ssh/ssh_host_ed25519_key}
          export RULES="''${AGENIX_RULES}"

          FLAKE_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")

          secrets-generate() {
            ${secrets-generate}/bin/secrets-generate --write "$@"
          }

          secrets-edit() {
            ${secrets-edit}/bin/secrets-edit "$@"
          }

          secrets-rekey() {
            ${secrets-rekey}/bin/secrets-rekey "$@"
          }

          secrets-validate() {
            ${secrets-validate}/bin/secrets-validate "$@"
          }

          secrets-new() {
            ${secrets-new}/bin/secrets-new "$@"
          }

          echo ""
          echo "=== Secrets DevShell ==="
          echo "Available commands (run from repo root):"
          echo "  secrets-generate    → regenerate secrets/secrets.nix from catalog"
          echo "  secrets-edit <file> → create/edit an encrypted secret"
          echo "  secrets-rekey       → rekey all secrets using 1Password"
          echo "  secrets-validate    → validate catalog vs secrets.nix vs files"
          echo "  secrets-new <path>  → interactive secret creation workflow"
          echo ""
          echo "Also available via nix run .#secrets-<cmd>"
          echo ""
        '';
      };

      packages = {
        inherit
          secrets-generate
          secrets-edit
          secrets-rekey
          secrets-validate
          secrets-new;
      };

      apps = {
        secrets-generate = { type = "app"; program = "${secrets-generate}/bin/secrets-generate"; meta.description = "Regenerate secrets/secrets.nix from catalog (outputs to stdout)"; };
        secrets-edit = { type = "app"; program = "${secrets-edit}/bin/secrets-edit"; meta.description = "Create/edit an encrypted .age file"; };
        secrets-rekey = { type = "app"; program = "${secrets-rekey}/bin/secrets-rekey"; meta.description = "Rekey all secrets using 1Password"; };
        secrets-validate = { type = "app"; program = "${secrets-validate}/bin/secrets-validate"; meta.description = "Validate catalog vs secrets.nix vs .age files"; };
        secrets-new = { type = "app"; program = "${secrets-new}/bin/secrets-new"; meta.description = "Interactive secret creation workflow"; };
      };
    };
}
