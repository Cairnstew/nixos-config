{ inputs, lib, ... }:
{
  flake.cloudHosts = {
    aws-webserver = {
      instance_type = "t3.micro";
      nixos_release = "24.11";
    };
    aws-bastion = {
      instance_type = "t3.micro";
      nixos_release = "24.11";
    };
  };

  perSystem = { pkgs, system, ... }:
  let
    unstable = inputs.nixpkgs-unstable.legacyPackages.${system};  # ← use unstable for cached binaries

    awsHosts = inputs.self.cloudHosts;

    hostsVar = hosts: builtins.toJSON hosts;

    mkTfApp = hosts: {
      type = "app";
      program = toString (pkgs.writeShellScript "tf" ''
        set -e
        
        # Capture original terraform directory before changing dirs
        ORIG_TFDIR=$(pwd)
        
        # Work in a temp directory to avoid Nix sandbox read-only restrictions
        TFDIR=$(mktemp -d)
        trap "rm -rf $TFDIR" EXIT
        
        # Copy terraform files to temp directory
        cp -r "$ORIG_TFDIR"/* "$TFDIR/" 2>/dev/null || true
        cd "$TFDIR"
        
        # Set TF_DATA_DIR for provider cache/plugins
        export TF_DATA_DIR="''${TF_DATA_DIR:-/tmp/terraform-data}"
        mkdir -p "$TF_DATA_DIR"
        
        # Load AWS credentials from agenix secrets if available
        # The aws-labs.age file should contain lines like:
        # export AWS_ACCESS_KEY_ID=...
        # export AWS_SECRET_ACCESS_KEY=...
        SECRETS_FILE="${toString ./../../secrets}/aws-labs.age"
        if [ -f "$SECRETS_FILE" ]; then
          set +e
          source <(${inputs.agenix.packages.${system}.agenix}/bin/agenix -d "$SECRETS_FILE")
          set -e
        fi
        
        # Pick the subcommand (e.g., init, plan, apply)
        ACTION=$1
        shift # Remove the action from the arguments list

        ${unstable.opentofu}/bin/tofu "$ACTION" \
            -var="flake_root=${toString ./../../.}" \
            -var='cloud_hosts=${hostsVar hosts}' \
            "$@"
        
        # Copy lock file back to original directory
        if [ -f "$TFDIR/.terraform.lock.hcl" ]; then
          cp -f "$TFDIR/.terraform.lock.hcl" "$ORIG_TFDIR/.terraform.lock.hcl"
        fi
        '');
    };
  in {
    apps = {
      tf = mkTfApp awsHosts;
    } // lib.mapAttrs' (name: _: {
      name = "tf-${name}";
      value = mkTfApp { ${name} = awsHosts.${name}; };
    }) awsHosts;

    devShells.terraform = pkgs.mkShell {
      buildInputs = [ unstable.opentofu unstable.awscli2 ];  # ← same for the devshell
    };
  };
}