{ inputs, lib, config, ... }:

let
  hostsWithSecrets = lib.filterAttrs
    (_: cfg: cfg.config.my.secrets.enable or false)
    config.flake.nixosConfigurations;

  secretsJson = builtins.toJSON (lib.mapAttrs (_: cfg:
    let s = cfg.config.my.secrets.names;
    in {
      aws = {
        credsPath  = cfg.config.age.secrets.${s.aws_cloud.apiKey}.path;
        sshPubPath = cfg.config.age.secrets.${s.aws_cloud.sshPubKey}.path;
        sshKeyPath = cfg.config.age.secrets.${s.aws_cloud.sshKey}.path;
      };
    }
  ) hostsWithSecrets);

  cloudConfigs = lib.filterAttrs
    (_: cfg: cfg.config.my.cloud-vm.enable or false)
    config.flake.nixosConfigurations;

  hostsVar = lib.mapAttrs (_: cfg:
    let vm = cfg.config.my.cloud-vm;
    in {
      provider      = vm.provider;
      region        = vm.region;
      instance_type = vm.instanceType;
      nixos_release = vm.nixosRelease;
    }
  ) cloudConfigs;

  usedProviders = lib.unique
    (lib.mapAttrsToList (_: cfg: cfg.config.my.cloud-vm.provider) cloudConfigs);

in
{
  flake.cloudHosts = hostsVar;

  perSystem = { pkgs, system, ... }:
  let
    unstable      = inputs.nixpkgs-unstable.legacyPackages.${system};
    nixos-anywhere = inputs.nixos-anywhere.packages.${system}.nixos-anywhere;

    # ── Secrets block ─────────────────────────────────────────────────────
    mkSecretsBlock = providers:
      let
        providerBlock = lib.concatMapStrings (p: ''
          CREDS_PATH=$(echo "$HOST_SECRETS" | ${pkgs.jq}/bin/jq -r '.${p}.credsPath')
          SSH_KEY_PATH=$(echo "$HOST_SECRETS" | ${pkgs.jq}/bin/jq -r '.${p}.sshKeyPath')
          SSH_PUB_PATH=$(echo "$HOST_SECRETS" | ${pkgs.jq}/bin/jq -r '.${p}.sshPubPath')

          if [ -f "$CREDS_PATH" ]; then
            set -a
            source "$CREDS_PATH"
            set +a
          else
            echo "WARNING: creds for '${p}' not found at $CREDS_PATH" >&2
          fi

          if [ -f "$SSH_PUB_PATH" ]; then
            export TF_VAR_ssh_public_keys_${p}="$(cat "$SSH_PUB_PATH")"
          else
            echo "WARNING: ssh pub key for '${p}' not found at $SSH_PUB_PATH" >&2
          fi
        '') providers;
      in
      ''
        CURRENT_HOST=$(hostname)
        HOST_SECRETS=$(echo '${secretsJson}' \
          | ${pkgs.jq}/bin/jq -r ".[\"$CURRENT_HOST\"]")

        if [ "$HOST_SECRETS" = "null" ]; then
          echo "ERROR: host '$CURRENT_HOST' not found in nixosConfigurations" \
               "or has no secrets configured" >&2
          exit 1
        fi

        ${providerBlock}
      '';

    # ── Terraform app ─────────────────────────────────────────────────────
    mkTfApp = hosts: {
      type    = "app";
      program = toString (pkgs.writeShellScript "tf" ''
        set -e

        REPO_ROOT=$(pwd)
        ORIG_TFDIR="$REPO_ROOT/terraform"
        TFDIR=$(mktemp -d)
        trap "rm -rf $TFDIR" EXIT

        cp -r "$ORIG_TFDIR"/. "$TFDIR/"
        cd "$TFDIR"

        export TF_DATA_DIR="''${TF_DATA_DIR:-$REPO_ROOT/terraform/.terraform}"
        mkdir -p "$TF_DATA_DIR"

        ${mkSecretsBlock usedProviders}

        ACTION=$1; shift
        ${unstable.opentofu}/bin/tofu "$ACTION" \
          -var='cloud_hosts=${builtins.toJSON hosts}' \
          "$@"

        if [ -f "$TFDIR/terraform.tfstate" ]; then
          cp -f "$TFDIR/terraform.tfstate" "$ORIG_TFDIR/terraform.tfstate"
        fi
        if [ -f "$TFDIR/terraform.tfstate.backup" ]; then
          cp -f "$TFDIR/terraform.tfstate.backup" "$ORIG_TFDIR/terraform.tfstate.backup"
        fi
        if [ -f "$TFDIR/.terraform.lock.hcl" ]; then
          cp -f "$TFDIR/.terraform.lock.hcl" "$ORIG_TFDIR/.terraform.lock.hcl"
        fi
      '');
    };

    # ── Deploy app ────────────────────────────────────────────────────────
    mkDeployApp = hostName:
      let
        # Read ssh key path for this host's provider at eval time
        sshKeyPath = "/run/agenix/aws-cloud-ssh-key"; # TODO: derive from provider
      in {
        type    = "app";
        program = toString (pkgs.writeShellScript "deploy-${hostName}" ''
          set -e

          REPO_ROOT=$(pwd)

          ${mkSecretsBlock usedProviders}

          IP=$(${unstable.opentofu}/bin/tofu \
            -chdir="$REPO_ROOT/terraform" \
            output -json \
            | ${pkgs.jq}/bin/jq -r '.aws_hosts.value["${hostName}"]')

          if [ -z "$IP" ] || [ "$IP" = "null" ]; then
            echo "ERROR: could not get IP for ${hostName} from tofu state" >&2
            exit 1
          fi

          echo "Deploying ${hostName} to $IP..."

          MODE="''${1:-switch}"

          if [ "$MODE" = "--first" ]; then
            ${nixos-anywhere}/bin/nixos-anywhere \
              --flake .#${hostName} \
              --ssh-option "IdentityFile=$SSH_KEY_PATH" \
              root@$IP
          else
            ${pkgs.nixos-rebuild}/bin/nixos-rebuild switch \
              --flake .#${hostName} \
              --target-host root@$IP \
              --build-host localhost \
              --ssh-option "IdentityFile=$SSH_KEY_PATH"
          fi
        '');
      };

  in {
    apps =
      { tf = mkTfApp hostsVar; }
      // lib.mapAttrs' (name: _: {
           name  = "tf-${name}";
           value = mkTfApp { ${name} = hostsVar.${name}; };
         }) hostsVar
      // lib.mapAttrs' (name: _: {
           name  = "deploy-${name}";
           value = mkDeployApp name;
         }) hostsVar;

    devShells.terraform = pkgs.mkShell {
      buildInputs = [ unstable.opentofu unstable.awscli2 pkgs.jq nixos-anywhere ];
    };
  };
}