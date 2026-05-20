# =============================================================================
# terranix.nix — Infrastructure-as-Code (Terraform) Integration
# =============================================================================
# Purpose: Provides a NixOS module for Terraform state management and exposes
#          Terraform workflows via flake apps and devShell.
#
# Inputs:
#   - inputs.terranix — Nix-to-Terraform configuration generator
#
# Outputs:
#   - flake.nixosModules.terraformInfra — system module for Terraform setup
#   - perSystem.devShells.default — shell with terraform, jq, gcloud
#   - perSystem.apps.tf* — apps: tf, tf-plan, tf-apply, tf-destroy, tf-show-config
#   - perSystem.packages.tf-config — generated Terraform JSON config
#
# State: Persisted to ~/.local/share/terraform/nixos-infra
# =============================================================================

{ self, inputs, lib, ... }:

let
  stateDir = "$HOME/.local/share/terraform/nixos-infra";
in
{
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
        modules = [
          self.nixosModules.terraform
        ];
      };

      tfRunner = pkgs.writeShellScriptBin "tf" ''
        set -euo pipefail

        if [ $# -eq 0 ]; then
          echo "Usage: nix run .#tf -- <command> [options]"
          echo "Commands: plan, apply, destroy, import, show-config"
          exit 1
        fi

        COMMAND="$1"

        if [ "$COMMAND" = "show-config" ]; then
          exec ${pkgs.jq}/bin/jq . ${terraformConfiguration}
        fi

        STATE_DIR="${stateDir}"
        WORK_DIR="$(mktemp -d)"

        # Always persist state back on exit, whether success or failure
        persist_state() {
          echo "==> persisting state"
          [[ -f "$WORK_DIR/terraform.tfstate"   ]] && cp "$WORK_DIR/terraform.tfstate"   "$STATE_DIR/"
          [[ -f "$WORK_DIR/.terraform.lock.hcl" ]] && cp "$WORK_DIR/.terraform.lock.hcl" "$STATE_DIR/"
          [[ -d "$WORK_DIR/.terraform"          ]] && cp -r "$WORK_DIR/.terraform"        "$STATE_DIR/"
          rm -rf "$WORK_DIR"
        }
        trap persist_state EXIT

        mkdir -p "$STATE_DIR"

        cp ${terraformConfiguration} "$WORK_DIR/config.tf.json"

        for f in terraform.tfstate .terraform.lock.hcl; do
          [[ -f "$STATE_DIR/$f" ]] && cp "$STATE_DIR/$f" "$WORK_DIR/"
        done
        [[ -d "$STATE_DIR/.terraform" ]] && cp -r "$STATE_DIR/.terraform" "$WORK_DIR/"

        cd "$WORK_DIR"

        if [[ -d "$STATE_DIR/.terraform" ]]; then
          echo "==> terraform init (cached)"
          ${pkgs.terraform}/bin/terraform init -lockfile=readonly
        else
          echo "==> terraform init (fresh)"
          ${pkgs.terraform}/bin/terraform init
        fi

        echo "==> terraform $@"
        ${pkgs.terraform}/bin/terraform "$@"
      '';

      mkAlias = name: args: {
        type = "app";
        program = "${pkgs.writeShellScriptBin name ''
          exec ${tfRunner}/bin/tf ${args} "$@"
        ''}/bin/${name}";
      };

    in
    {
      devShells.default = pkgs.mkShell {
        packages = [ pkgs.terraform pkgs.jq pkgs.openssh pkgs.google-cloud-sdk ];
        shellHook = ''
          echo "Terraform infra dev shell"
          echo "  nix run .#tf -- plan"
          echo "  nix run .#tf -- apply"
          echo "  nix run .#tf -- destroy"
          echo "  nix run .#tf -- import <resource> <id>"
          echo "  nix run .#tf -- show-config"
          echo ""
          echo "  State dir: ${stateDir}"
        '';
      };

      apps = {
        tf = { type = "app"; program = "${tfRunner}/bin/tf"; };
        tf-plan = mkAlias "tf-plan" "plan";
        tf-apply = mkAlias "tf-apply" "apply -auto-approve";
        tf-destroy = mkAlias "tf-destroy" "destroy -auto-approve";
        tf-show-config = mkAlias "tf-show-config" "show-config";
      };

      packages.tf-config = terraformConfiguration;
    };
}
