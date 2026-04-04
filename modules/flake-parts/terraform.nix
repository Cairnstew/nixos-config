{ inputs, lib, config, ... }:

let
  # ── All hosts that have secrets enabled ───────────────────────────────────
  # Baked in at eval time as a JSON map of hostname → provider secret paths
  hostsWithSecrets = lib.filterAttrs
    (_: cfg: cfg.config.my.secrets.enable or false)
    config.flake.nixosConfigurations;

  secretsJson = builtins.toJSON (lib.mapAttrs (_: cfg:
    let s = cfg.config.my.secrets.names;
    in {
      aws = {
        credsPath  = cfg.config.age.secrets.${s.aws_labs.apiKey}.path;
        sshPubPath = cfg.config.age.secrets.${s.aws_labs.sshPubKey}.path;
        sshKeyPath = cfg.config.age.secrets.${s.aws_labs.sshKey}.path;
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

in
{
  flake.cloudHosts = hostsVar;

  perSystem = { pkgs, system, ... }:
  let
    unstable = inputs.nixpkgs-unstable.legacyPackages.${system};

    # ── Secrets block — resolved at runtime via hostname ────────────────────
    mkSecretsBlock = providers:
      let
        providerBlock = lib.concatMapStrings (p: ''
          CREDS_PATH=$(echo "$HOST_SECRETS" | ${pkgs.jq}/bin/jq -r '.${p}.credsPath')
          SSH_PUB_PATH=$(echo "$HOST_SECRETS" | ${pkgs.jq}/bin/jq -r '.${p}.sshPubPath')

          if [ -f "$CREDS_PATH" ]; then
            source "$CREDS_PATH"
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

    mkTfApp = hosts: {
      type    = "app";
      program = toString (pkgs.writeShellScript "tf" ''
        set -e

        ORIG_TFDIR=$(pwd)/terraform
        TFDIR=$(mktemp -d)
        trap "rm -rf $TFDIR" EXIT

        cp -r "$ORIG_TFDIR"/. "$TFDIR/"

        export TF_DATA_DIR="''${TF_DATA_DIR:-$(pwd)/terraform/.terraform}"
        mkdir -p "$TF_DATA_DIR"

        ${mkSecretsBlock usedProviders}

        ACTION=$1; shift
        ${unstable.opentofu}/bin/tofu "$ACTION" \
          -var='cloud_hosts=${builtins.toJSON hosts}' \
          "$@"

        if [ -f "$TFDIR/.terraform.lock.hcl" ]; then
          cp -f "$TFDIR/.terraform.lock.hcl" "$ORIG_TFDIR/.terraform.lock.hcl"
        fi
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
      buildInputs = [ unstable.opentofu unstable.awscli2 pkgs.jq ];
    };
  };
}