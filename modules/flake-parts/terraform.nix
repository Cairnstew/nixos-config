{ inputs, lib, ... }:

let
  # ── Cloud provider definitions ─────────────────────────────────────────────
  # Add new providers here. Each entry needs:
  #   secretsPath  – runtime path agenix decrypts to
  #   region       – default region (can be overridden per-host)
  providers = {
    aws-labs = {
      secretsPath = "/run/agenix/aws-labs";
      region      = "eu-west-1";
    };
    # aws-prod = {
    #   secretsPath = "/run/agenix/aws-prod";
    #   region      = "us-east-1";
    # };
    # gcp = {
    #   secretsPath = "/run/agenix/gcp-creds";
    #   region      = "europe-west2";
    # };
  };

  # ── Cloud host definitions ─────────────────────────────────────────────────
  # Each host specifies which provider it belongs to.
  cloudHosts = {
    aws-webserver = {
      provider      = "aws-labs";
      instance_type = "t3.micro";
      nixos_release = "24.11";
    };
    aws-bastion = {
      provider      = "aws-labs";
      instance_type = "t3.micro";
      nixos_release = "24.11";
    };
    # gcp-worker = {
    #   provider      = "gcp";
    #   instance_type = "e2-micro";
    #   nixos_release = "24.11";
    # };
  };

in
{
  flake.cloudHosts = cloudHosts;
  flake.cloudProviders = providers;

  perSystem = { pkgs, system, ... }:
  let
    unstable = inputs.nixpkgs-unstable.legacyPackages.${system};

    hostsVar = hosts:
      # Strip the provider field before passing to tofu — it's flake-only metadata
      builtins.toJSON (lib.mapAttrs (_: h: removeAttrs h [ "provider" ]) hosts);

    mkSecretsBlock = hosts:
      # Collect the unique set of providers used by these hosts and source each
      let
        usedProviders = lib.unique (lib.mapAttrsToList (_: h: h.provider) hosts);
      in lib.concatMapStrings (p:
        let secretsPath = providers.${p}.secretsPath;
        in ''
          if [ -f "${secretsPath}" ]; then
            source "${secretsPath}"
          else
            echo "WARNING: secrets file for provider '${p}' not found at ${secretsPath}" >&2
          fi
        ''
      ) usedProviders;

    mkTfApp = hosts: {
      type = "app";
      program = toString (pkgs.writeShellScript "tf" ''
        set -e

        ORIG_TFDIR=$(pwd)

        TFDIR=$(mktemp -d)
        trap "rm -rf $TFDIR" EXIT

        cp -r "$ORIG_TFDIR"/* "$TFDIR/" 2>/dev/null || true
        cd "$TFDIR"

        export TF_DATA_DIR="''${TF_DATA_DIR:-/tmp/terraform-data}"
        mkdir -p "$TF_DATA_DIR"

        ${mkSecretsBlock hosts}

        ACTION=$1
        shift

        ${unstable.opentofu}/bin/tofu "$ACTION" \
            -var='cloud_hosts=${hostsVar hosts}' \
            "$@"

        if [ -f "$TFDIR/.terraform.lock.hcl" ]; then
          cp -f "$TFDIR/.terraform.lock.hcl" "$ORIG_TFDIR/.terraform.lock.hcl"
        fi
      '');
    };

  in {
    apps = {
      tf = mkTfApp cloudHosts;
    } // lib.mapAttrs' (name: _: {
      name  = "tf-${name}";
      value = mkTfApp { ${name} = cloudHosts.${name}; };
    }) cloudHosts;

    devShells.terraform = pkgs.mkShell {
      buildInputs = [ unstable.opentofu unstable.awscli2 ];
    };
  };
}