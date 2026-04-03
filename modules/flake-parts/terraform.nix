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
        cd ${toString ./../../terraform}
        
        # Pick the subcommand (e.g., init, plan, apply)
        ACTION=$1
        shift # Remove the action from the arguments list

        exec ${unstable.opentofu}/bin/tofu "$ACTION" \
            -var="flake_root=${toString ./../../.}" \
            -var='cloud_hosts=${hostsVar hosts}' \
            "$@"
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