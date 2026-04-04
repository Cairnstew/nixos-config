{ inputs, lib, ... }:

let
  # ── Derive cloud hosts from nixosConfigurations ────────────────────────────
  # Any NixOS host with my.cloud-vm.enable = true is automatically included.
  cloudConfigs = lib.filterAttrs
    (_: cfg: cfg.config.my.cloud-vm.enable or false)
    inputs.self.nixosConfigurations;

  # The var object passed to tofu — strip secretsPath, it's deploy-machine-only
  hostsVar = lib.mapAttrs (_: cfg:
    let vm = cfg.config.my.cloud-vm;
    in {
      provider      = vm.provider;
      region        = vm.region;
      instance_type = vm.instanceType;
      nixos_release = vm.nixosRelease;
    }
  ) cloudConfigs;

  # Source each unique secrets file (deduplicated across hosts sharing a provider)
  mkSecretsBlock =
    let
      uniquePaths = lib.unique
        (lib.mapAttrsToList (_: cfg: cfg.config.my.cloud-vm.secretsPath) cloudConfigs);
    in
    lib.concatMapStrings (secretsPath: ''
      if [ -f "${secretsPath}" ]; then
        source "${secretsPath}"
      else
        echo "WARNING: secrets not found at ${secretsPath}" >&2
      fi
    '') uniquePaths;

in
{
  # Expose for other flake outputs that may want to inspect the host list
  flake.cloudHosts = hostsVar;

  perSystem = { pkgs, system, ... }:
  let
    unstable = inputs.nixpkgs-unstable.legacyPackages.${system};

    mkTfApp = hosts: {
      type    = "app";
      program = toString (pkgs.writeShellScript "tf" ''
        set -e

        ORIG_TFDIR=$(pwd)/terraform          # ← point at terraform/
        TFDIR=$(mktemp -d)
        trap "rm -rf $TFDIR" EXIT

        cp -r "$ORIG_TFDIR"/* "$TFDIR/"
        cd "$TFDIR"

        export TF_DATA_DIR="''${TF_DATA_DIR:-/tmp/terraform-data}"
        mkdir -p "$TF_DATA_DIR"

        ${mkSecretsBlock}

        ACTION=$1; shift
        ${unstable.opentofu}/bin/tofu "$ACTION" \
          -var='cloud_hosts=${builtins.toJSON hosts}' \
          "$@"

        [ -f "$TFDIR/.terraform.lock.hcl" ] &&
          cp -f "$TFDIR/.terraform.lock.hcl" "$ORIG_TFDIR/.terraform.lock.hcl"
      '');
    };


  in {
    apps =
      { tf = mkTfApp hostsVar; }
      // lib.mapAttrs' (name: _: {
           name  = "tf-${name}";
           value = mkTfApp { ${name} = hostsVar.${name}; };
         }) hostsVar;

    devShells.terraform = pkgs.mkShell {
      buildInputs = [ unstable.opentofu unstable.awscli2 ];
    };
  };
}