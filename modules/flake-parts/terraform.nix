{ inputs, lib, config, ... }:

let
  # ── All hosts that have secrets enabled ───────────────────────────────────
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
      # google = {
      #   credsPath  = cfg.config.age.secrets.${s.gcp.apiKey}.path;
      #   sshPubPath = cfg.config.age.secrets.${s.gcp.sshPubKey}.path;
      #   sshKeyPath = cfg.config.age.secrets.${s.gcp.sshKey}.path;
      # };
    }
  ) hostsWithSecrets);

  # ── Cloud hosts derived from nixosConfigurations ──────────────────────────
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

  # ── Terranix config — generated from nixosConfigurations ─────────────────
  # Takes a filtered subset of hostsVar and produces a config.tf.json
  mkTerranixConfig = hosts: system:
    let
      awsHosts    = lib.filterAttrs (_: h: h.provider == "aws")    hosts;
      googleHosts = lib.filterAttrs (_: h: h.provider == "google") hosts;
    in
    inputs.terranix.lib.terranixConfiguration {
      inherit system;
      modules = [
        ./terranix/default.nix
        {
          # AWS hosts — ssh_public_key injected at runtime via TF_VAR
          cloud.aws.hosts = lib.mapAttrs (_: h: {
            instance_type  = h.instance_type;
            region         = h.region;
            nixos_release  = h.nixos_release;
            ssh_public_key = "\${var.ssh_public_key_aws}";
          }) awsHosts;

          # Google hosts
          # cloud.google.hosts = lib.mapAttrs (_: h: {
          #   machine_type   = h.instance_type;
          #   region         = h.region;
          #   zone           = "${h.region}-a";
          #   nixos_release  = h.nixos_release;
          #   project        = "my-gcp-project";
          #   ssh_public_key = "\${var.ssh_public_key_google}";
          # }) googleHosts;
        }

        # ── Terraform variable declarations ─────────────────────────────────
        # These receive values from TF_VAR_* env vars set by mkSecretsBlock
        {
          variable.ssh_public_key_aws = {
            type      = "string";
            default   = "";
            sensitive = true;
          };
          # variable.ssh_public_key_google = {
          #   type      = "string";
          #   default   = "";
          #   sensitive = true;
          # };
        }
      ];
    };

in
{
  flake.cloudHosts = hostsVar;

  perSystem = { pkgs, system, ... }:
  let
    unstable       = inputs.nixpkgs-unstable.legacyPackages.${system};
    nixos-anywhere = inputs.nixos-anywhere.packages.${system}.nixos-anywhere;

    # ── Secrets block — resolved at runtime via hostname ──────────────────
    mkSecretsBlock = providers:
      let
        providerBlock = lib.concatMapStrings (p: ''
          CREDS_PATH=$(echo "$HOST_SECRETS" | ${pkgs.jq}/bin/jq -r '.${p}.credsPath')
          SSH_PUB_PATH=$(echo "$HOST_SECRETS" | ${pkgs.jq}/bin/jq -r '.${p}.sshPubPath')
          SSH_KEY_PATH=$(echo "$HOST_SECRETS" | ${pkgs.jq}/bin/jq -r '.${p}.sshKeyPath')

          if [ -f "$CREDS_PATH" ]; then
            set -a
            source "$CREDS_PATH"
            set +a
          else
            echo "WARNING: creds for '${p}' not found at $CREDS_PATH" >&2
          fi

          if [ -f "$SSH_PUB_PATH" ]; then
            export TF_VAR_ssh_public_key_${p}="$(cat "$SSH_PUB_PATH")"
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
        TFDIR=$(mktemp -d)
        trap "rm -rf $TFDIR" EXIT

        # Write terranix-generated config.tf.json into temp dir
        cp ${mkTerranixConfig hosts system} "$TFDIR/config.tf.json"

        # Carry over existing state if present
        [ -f "$REPO_ROOT/terraform.tfstate" ] && \
          cp "$REPO_ROOT/terraform.tfstate" "$TFDIR/terraform.tfstate"

        export TF_DATA_DIR="''${TF_DATA_DIR:-$REPO_ROOT/.terraform}"
        mkdir -p "$TF_DATA_DIR"

        cd "$TFDIR"

        ${mkSecretsBlock usedProviders}

        ACTION=$1; shift
        ${unstable.opentofu}/bin/tofu "$ACTION" "$@"

        # Copy state back so it persists across runs
        [ -f "$TFDIR/terraform.tfstate" ] && \
          cp -f "$TFDIR/terraform.tfstate" "$REPO_ROOT/terraform.tfstate"
        [ -f "$TFDIR/terraform.tfstate.backup" ] && \
          cp -f "$TFDIR/terraform.tfstate.backup" "$REPO_ROOT/terraform.tfstate.backup"
      '');
    };

    # ── Deploy app ────────────────────────────────────────────────────────
    mkDeployApp = hostName: {
      type    = "app";
      program = toString (pkgs.writeShellScript "deploy-${hostName}" ''
        set -e

        REPO_ROOT=$(pwd)

        ${mkSecretsBlock usedProviders}

        # Read SSH key path from resolved secrets
        CURRENT_HOST=$(hostname)
        HOST_SECRETS=$(echo '${secretsJson}' \
          | ${pkgs.jq}/bin/jq -r ".[\"$CURRENT_HOST\"]")
        SSH_KEY_PATH=$(echo "$HOST_SECRETS" \
          | ${pkgs.jq}/bin/jq -r '.aws.sshKeyPath')

        # Get IP from tofu state
        IP=$(${unstable.opentofu}/bin/tofu \
          -chdir="$REPO_ROOT" \
          output -json \
          | ${pkgs.jq}/bin/jq -r '."${hostName}".value // empty')

        if [ -z "$IP" ]; then
          echo "ERROR: could not get IP for ${hostName} from tofu state" >&2
          exit 1
        fi

        echo "Deploying ${hostName} to $IP..."

        MODE="''${1:-switch}"

        if [ "$MODE" = "--first" ]; then
          ${nixos-anywhere}/bin/nixos-anywhere \
            --flake .#${hostName} \
            --build-on-remote \
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
      buildInputs = [
        unstable.opentofu
        unstable.awscli2
        pkgs.jq
        nixos-anywhere
      ];
    };
  };
}