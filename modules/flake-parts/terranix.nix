{ self, inputs, lib, ... }:

let
  # Where Terraform state/lock/providers live on the host.
  # Uses $HOME so it works for normal users without root.
  # Override to /var/lib/terraform/state for a CI/server environment.
  stateDir = "$HOME/.local/share/terraform/${self.shortRev or "dirty"}";
in
{
  # ── NixOS module: only needed on servers/CI that run tf as a service ──────
  flake.nixosModules.terraformInfra = { ... }: {
    users.groups.terraform = { };
    systemd.tmpfiles.rules = [
      "d  /var/lib/terraform        0750  root  terraform  -  -"
      "d  /var/lib/terraform/state  2770  root  terraform  -  -"
    ];
  };

  perSystem = { system, pkgs, ... }:
    let
      terraformConfiguration = inputs.terranix.lib.terranixConfiguration {
        inherit system;
        modules = [ self.nixosModules.terraform ];
      };

      # Shared wrapper: stage config + existing state in a tmpdir,
      # run `body`, optionally flush state back.
      mkTfScript = { name, body, writeState ? false }:
        pkgs.writeShellScript name ''
          set -euo pipefail

          STATE_DIR="${stateDir}"
          WORK_DIR="$(mktemp -d)"
          trap 'rm -rf "$WORK_DIR"' EXIT

          mkdir -p "$STATE_DIR"

          # Lay down the generated Terraform JSON
          cp ${terraformConfiguration} "$WORK_DIR/config.tf.json"

          # Restore persisted state artefacts
          for f in terraform.tfstate .terraform.lock.hcl; do
            [[ -f "$STATE_DIR/$f" ]] && cp "$STATE_DIR/$f" "$WORK_DIR/"
          done
          [[ -d "$STATE_DIR/.terraform" ]] && cp -r "$STATE_DIR/.terraform" "$WORK_DIR/"

          cd "$WORK_DIR"

          # Init: use cached providers if available, otherwise full init
          if [[ -d "$STATE_DIR/.terraform" ]]; then
            echo "==> terraform init (cached)"
            ${pkgs.terraform}/bin/terraform init -lockfile=readonly
          else
            echo "==> terraform init (fresh)"
            ${pkgs.terraform}/bin/terraform init
          fi

          # Always persist lock file + provider cache after init
          [[ -f ".terraform.lock.hcl" ]] && cp    ".terraform.lock.hcl" "$STATE_DIR/"
          [[ -d ".terraform"          ]] && cp -r ".terraform"           "$STATE_DIR/"

          ${body}

          ${lib.optionalString writeState ''
            echo "==> persisting state"
            [[ -f "terraform.tfstate" ]] && cp "terraform.tfstate" "$STATE_DIR/"
          ''}
        '';

    in
    {
      # ── Dev shell ───────────────────────────────────────────────────────────
      devShells.default = pkgs.mkShell {
        packages = [
          pkgs.terraform
          pkgs.jq
          pkgs.openssh
        ];
        shellHook = ''
          echo "Terraform infra dev shell"
          echo "  nix run .#tf-plan"
          echo "  nix run .#tf-apply"
          echo "  nix run .#tf-destroy"
          echo "  nix run .#tf-show-config"
        '';
      };

      # ── Apps ────────────────────────────────────────────────────────────────
      apps = {
        tf-plan = {
          type = "app";
          program = toString (mkTfScript {
            name = "tf-plan";
            body = ''
              echo "==> terraform plan"
              ${pkgs.terraform}/bin/terraform plan
            '';
          });
        };

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

      # ── Expose generated JSON as a buildable package ────────────────────────
      packages.tf-config = terraformConfiguration;
    };
}