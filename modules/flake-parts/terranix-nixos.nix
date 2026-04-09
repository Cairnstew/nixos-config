# modules/flake-parts/terranix.nix
#
# Terranix flake-parts module.
# Terraform config lives in ./terraform/ at the repo root.
# State/lock/providers are persisted to `stateDir` on the host.
#
# Usage:
#   nix run .#tf-plan
#   nix run .#tf-apply
#   nix run .#tf-destroy
#   nix run .#tf-show-config
{ self, inputs, lib, ... }:

let
  # ── Tunables ────────────────────────────────────────────────────────────────
  # Directory on the host where .tfstate / .lock.hcl / .terraform/ live.
  stateDir = "/var/lib/terraform/state";

  # Root-relative path to your Terranix module tree.
  terraformModulesPath = self.nixosModules.terraform;
in
{
  perSystem = { system, pkgs, ... }:
    let
      terraformConfiguration = inputs.terranix.lib.terranixConfiguration {
        inherit system;
        modules = [ terraformModulesPath ];
      };

      # Shared helper: copy config + existing state into a tmpdir, run `body`,
      # then flush state back to stateDir.
      mkTfScript = { name, body, writeState ? false }:
        pkgs.writeShellScript name ''
          set -euo pipefail

          STATE_DIR="${stateDir}"
          WORK_DIR="$(mktemp -d)"
          trap 'rm -rf "$WORK_DIR"' EXIT

          mkdir -p "$STATE_DIR"

          # Generated Terraform JSON
          cp ${terraformConfiguration} "$WORK_DIR/config.tf.json"

          # Restore persisted state artefacts (best-effort)
          [[ -f "$STATE_DIR/terraform.tfstate"   ]] && cp    "$STATE_DIR/terraform.tfstate"   "$WORK_DIR/"
          [[ -f "$STATE_DIR/.terraform.lock.hcl" ]] && cp    "$STATE_DIR/.terraform.lock.hcl" "$WORK_DIR/"
          [[ -d "$STATE_DIR/.terraform"          ]] && cp -r "$STATE_DIR/.terraform"           "$WORK_DIR/"

          cd "$WORK_DIR"

          echo "==> terraform init"
          ${pkgs.terraform}/bin/terraform init \
            -lockfile=readonly 2>/dev/null \
            || ${pkgs.terraform}/bin/terraform init

          # Always persist lock + provider cache after init
          [[ -f "$WORK_DIR/.terraform.lock.hcl" ]] && cp    "$WORK_DIR/.terraform.lock.hcl" "$STATE_DIR/"
          [[ -d "$WORK_DIR/.terraform"          ]] && cp -r "$WORK_DIR/.terraform"           "$STATE_DIR/"

          ${body}

          ${lib.optionalString writeState ''
            echo "==> persisting state"
            [[ -f "$WORK_DIR/terraform.tfstate" ]] && cp "$WORK_DIR/terraform.tfstate" "$STATE_DIR/"
          ''}
        '';

    in
    {
      apps = {
        tf-apply = {
          type = "app";
          program = toString (mkTfScript {
            name = "tf-apply";
            writeState = true;
            body = ''
              echo "==> terraform apply"
              ${pkgs.terraform}/bin/terraform apply
            '';
          });
        };

        tf-plan = {
          type = "app";
          program = toString (mkTfScript {
            name = "tf-plan";
            writeState = false;
            body = ''
              echo "==> terraform plan"
              ${pkgs.terraform}/bin/terraform plan
            '';
          });
        };

        tf-destroy = {
          type = "app";
          program = toString (mkTfScript {
            name = "tf-destroy";
            writeState = true;
            body = ''
              echo "==> terraform destroy"
              ${pkgs.terraform}/bin/terraform destroy
            '';
          });
        };

        tf-show-config = {
          type = "app";
          program = toString (pkgs.writeShellScript "tf-show-config" ''
            ${pkgs.jq}/bin/jq . ${terraformConfiguration}
          '');
        };
      };

      # Expose the generated JSON as a package so `nix build .#tf-config` works
      packages.tf-config = terraformConfiguration;
    };
}
