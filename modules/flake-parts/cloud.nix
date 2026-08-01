# =============================================================================
# cloud.nix — Cloud Infrastructure-as-Code (terranix + OpenTofu) Integration
# =============================================================================
# Purpose: Declare cloud infrastructure (VMs, containers, services on GCP/AWS)
#          alongside NixOS hosts in the same flake.
#
# Inputs:
#   - inputs.terranix — Nix-to-Terraform configuration generator (flakeModule)
#
# Outputs (per configuration, e.g. `gcp`, `aws`):
#   - packages.<name>        — `nix run .#gcp`  → apply; `.plan`/`.destroy`/
#                               `.init` via passthru: `nix run .#gcp.plan`
#   - devShells.<name>       — shell with plan/apply/destroy/tofu on PATH
#   - packages.tf-config     — generated Terraform JSON for the gcp config
#   - apps.tf / tf-plan / tf-apply / tf-destroy — thin aliases (muscle memory)
#
# State: persisted per config in ~/.local/share/terraform/nixos-infra/<name>
#
# Usage:
#   nix run .#gcp -- plan
#   nix run .#gcp -- apply
#   nix run .#gcp -- destroy
#   nix run .#aws -- plan
# =============================================================================

{ inputs, ... }:

let
  # Absolute path so the generated wrapper's `mkdir -p ${workdir}` doesn't trip
  # shellcheck SC2086 (writeShellApplication fails on unquoted `$HOME`).
  # Single-user config — adjust if running as a different user.
  stateRoot = "/home/seanc/.local/share/terraform/nixos-infra";

  # Shared defaults, consumed by the wrapper's `prefixText` below.
  # (Keep these in sync with the per-provider configs in cloud/.)
  gcp = {
    project = "";
    region = "europe-west4";
    imageFamily = "nixos-25.05";
  };
  aws = {
    region = "eu-west-2";
  };

  # Thin aliases that forward to the `gcp` configuration wrapper so the old
  # `nix run .#tf -- <cmd>` muscle memory keeps working.
  mkTfAlias = { config, pkgs }: name: args: description: {
    type = "app";
    program = "${pkgs.writeShellScriptBin name ''
      exec ${config.terranix.terranixConfigurations.gcp.result.terraformWrapper}/bin/tofu ${args} "$@"
    ''}/bin/${name}";
    meta.description = description;
  };
in
{
  imports = [ inputs.terranix.flakeModule ];

  config.perSystem = { config, pkgs, ... }:
    {
      terranix.terranixConfigurations = {
        gcp = {
          modules = [ ../../cloud/gcp ];
          terraformWrapper.package = pkgs.opentofu;
          terraformWrapper.extraRuntimeInputs = [ pkgs.jq pkgs.google-cloud-sdk ];
          terraformWrapper.prefixText = ''
            # GCP credentials come from the agenix `gcloud-auth` secret
            # (guarded so CI builds / machines without secrets still evaluate).
            if [ -r /run/agenix/gcloud-auth ]; then
              export TF_VAR_gcp_credentials_file=/run/agenix/gcloud-auth
              ${if gcp.project != "" then
                "export TF_VAR_project=${gcp.project}"
              else
                "TF_VAR_project=$(jq -r .project_id /run/agenix/gcloud-auth) && export TF_VAR_project"}
            fi
            if [ -r /run/agenix/tailscale-authkey ]; then
              TF_VAR_tailscale_auth_key="$(cat /run/agenix/tailscale-authkey)"
              export TF_VAR_tailscale_auth_key
            fi
            # SSH pub key for first-boot access (used by stage-2 deploys)
            if [ -r /run/agenix/aws-ssh-pub-key ]; then
              TF_VAR_ssh_pub_key="$(cat /run/agenix/aws-ssh-pub-key)"
              export TF_VAR_ssh_pub_key
            fi
          '';
          workdir = "${stateRoot}/gcp";
        };

        aws = {
          modules = [ ../../cloud/aws ];
          terraformWrapper.package = pkgs.opentofu;
          terraformWrapper.prefixText = ''
            # aws-cloud secret is expected to be shell `KEY=VALUE` lines.
            if [ -r /run/agenix/aws-cloud ]; then
              set -a
              # shellcheck disable=SC1091
              . /run/agenix/aws-cloud
              set +a
            fi
            if [ -r /run/agenix/aws-ssh-pub-key ]; then
              TF_VAR_ssh_pub_key="$(cat /run/agenix/aws-ssh-pub-key)"
              export TF_VAR_ssh_pub_key
            fi
            export TF_VAR_region=${aws.region}
          '';
          workdir = "${stateRoot}/aws";
        };
      };

      packages.tf-config = config.terranix.terranixConfigurations.gcp.result.terraformConfiguration;

      apps = {
        tf = mkTfAlias { inherit config pkgs; } "tf" "" "Run OpenTofu against the gcp configuration (e.g. `nix run .#tf -- plan`)";
        tf-plan = mkTfAlias { inherit config pkgs; } "tf-plan" "plan" "Preview cloud infrastructure changes (terraform plan)";
        tf-apply = mkTfAlias { inherit config pkgs; } "tf-apply" "apply" "Apply cloud infrastructure changes";
        tf-destroy = mkTfAlias { inherit config pkgs; } "tf-destroy" "destroy" "Destroy cloud infrastructure";
        tf-show-config = {
          type = "app";
          program = "${pkgs.writeShellScriptBin "tf-show-config" ''
            exec ${pkgs.jq}/bin/jq . ${config.terranix.terranixConfigurations.gcp.result.terraformConfiguration}
          ''}/bin/tf-show-config";
          meta.description = "Print the generated Terraform JSON config (pretty-printed with jq)";
        };
      };
    };
}
