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

  perSystem = { pkgs, ... }:
  let
    awsHosts = inputs.self.cloudHosts;

    hostsVar = hosts: builtins.toJSON hosts;

    mkTfApp = hosts: {
      type = "app";
      program = toString (pkgs.writeShellScript "tf" ''
        set -e
        cd ${toString ./../../terraform}
        exec ${pkgs.opentofu}/bin/tofu \
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
      buildInputs = with pkgs; [ opentofu awscli2 ];
    };
  };
}