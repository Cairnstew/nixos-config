{ self, inputs, lib, ... }:

let
  stateDir = "$HOME/.local/share/terraform/${self.shortRev or "dirty"}";
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
        modules = [ self.nixosModules.terraform ];
      };

      tfRunner = pkgs.writeShellScriptBin "tf" ''
        set -euo pipefail

        if [ $# -eq 0 ]; then
          echo "Usage: nix run .#tf -- <command> [options]"
          echo "Commands: plan, apply, destroy, show-config"
          exit 1
        fi

        COMMAND="$1"

        if [ "$COMMAND" = "show-config" ]; then
          exec ${pkgs.jq}/bin/jq . ${terraformConfiguration}
        fi

        STATE_DIR="${stateDir}"
        WORK_DIR="$(mktemp -d)"
        trap 'rm -rf "$WORK_DIR"' EXIT

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

        [[ -f ".terraform.lock.hcl" ]] && cp    ".terraform.lock.hcl" "$STATE_DIR/"
        [[ -d ".terraform"          ]] && cp -r ".terraform"           "$STATE_DIR/"

        echo "==> terraform $@"
        ${pkgs.terraform}/bin/terraform "$@"

        if [ "$COMMAND" = "apply" ] || [ "$COMMAND" = "destroy" ]; then
          echo "==> persisting state"
          [[ -f "terraform.tfstate" ]] && cp "terraform.tfstate" "$STATE_DIR/"
        fi
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
        packages = [ pkgs.terraform pkgs.jq pkgs.openssh ];
        shellHook = ''
          echo "Terraform infra dev shell"
          echo "  nix run .#tf -- plan"
          echo "  nix run .#tf -- apply"
          echo "  nix run .#tf -- destroy"
          echo "  nix run .#tf -- show-config"
        '';
      };

      apps = {
        tf         = { type = "app"; program = "${tfRunner}/bin/tf"; };
        default    = { type = "app"; program = "${tfRunner}/bin/tf"; };
        tf-plan        = mkAlias "tf-plan"    "plan";
        tf-apply       = mkAlias "tf-apply"   "apply -auto-approve";
        tf-destroy     = mkAlias "tf-destroy" "destroy -auto-approve";
        tf-show-config = mkAlias "tf-show-config" "show-config";
      };

      packages.tf-config = terraformConfiguration;
    };
}