{ inputs, lib, ... }:
{
  perSystem = { pkgs, system, ... }:
  let
    # Filter nixosConfigurations to only cloud hosts
    cloudHosts = lib.filterAttrs
      (_: cfg: cfg.config.my.cloud-vm.enable)
      inputs.self.nixosConfigurations;

    awsHosts = lib.filterAttrs
      (_: cfg: cfg.config.my.cloud-vm.provider == "aws")
      cloudHosts;

    # Build the -var=cloud_hosts=... JSON for a given set of hosts
    hostsVar = hosts: builtins.toJSON (lib.mapAttrs (_: _: {
      instance_type = "t3.micro";
      nixos_release = "24.11";
    }) hosts);

    mkTfApp = hosts: pkgs.writeShellScript "tf" ''
      set -e
      cd ${toString ./../../terraform}
      exec ${pkgs.opentofu}/bin/tofu \
        -var="flake_root=${toString ./../../.}" \
        -var='cloud_hosts=${hostsVar hosts}' \
        "$@"
    '';
  in {
    # nix run .#tf -- apply  (all aws hosts)
    apps.tf = {
      type = "app";
      program = toString (mkTfApp awsHosts);
    };

    # nix run .#tf-aws-webserver -- apply  (single host)
    apps = lib.mapAttrs' (name: _: {
      name = "tf-${name}";
      value = {
        type = "app";
        program = toString (mkTfApp { ${name} = awsHosts.${name}; });
      };
    }) awsHosts;

    devShells.terraform = pkgs.mkShell {
      buildInputs = with pkgs; [ opentofu awscli2 ];
    };
  };
}