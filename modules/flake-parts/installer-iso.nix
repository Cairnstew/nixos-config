{ config, inputs, lib, ... }: {
  perSystem = { pkgs, system, ... }: let
    isoDir = ../../packages/installer-iso;
    configurationModule = "${toString isoDir}/configuration.nix";
    secretsDir = "${toString isoDir}/secrets";
    hasSecrets = builtins.pathExists (toString secretsDir);
    secrets = name: default:
      if hasSecrets then builtins.readFile ("${secretsDir}/${name}") else default;
  in {
    packages.installer-iso = (inputs.nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [
        "${pkgs.path}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
        configurationModule
        {
          isoImage.contents = [
            {
              source = pkgs.writeText "ts.key" (secrets "ts.key" "MISSING-SECRETS-RUN-just-build-iso");
              target = "/iso/ts.key";
            }
            {
              source = pkgs.writeText "authorized_keys" (secrets "authorized_keys" "MISSING-SECRETS");
              target = "/iso/authorized_keys";
            }
            {
              source = pkgs.writeText "ssh_host_ed25519_key" (secrets "ssh_host_ed25519_key" "MISSING-SECRETS");
              target = "/iso/ssh_host_ed25519_key";
            }
            {
              source = pkgs.writeText "ssh_host_ed25519_key.pub" (secrets "ssh_host_ed25519_key.pub" "MISSING-SECRETS");
              target = "/iso/ssh_host_ed25519_key.pub";
            }
          ];
        }
      ];
      specialArgs = { inherit inputs; };
    }).config.system.build.isoImage;

    apps.build-iso = {
      type = "app";
      program = pkgs.writeShellApplication {
        name = "build-installer-iso";
        runtimeInputs = [ inputs.agenix.packages.${system}.default pkgs.openssh ];
        text = ''
          set -euo pipefail

          FLAKE_ROOT="$PWD"
          SECRETS_DIR="$FLAKE_ROOT/packages/installer-iso/secrets"
          ISO_DIR="$FLAKE_ROOT/ISO"

          mkdir -p "$SECRETS_DIR" "$ISO_DIR"

          echo "-> Decrypting Tailscale auth key..."
          if [ -f "$FLAKE_ROOT/secrets/tailscale/authkey.age" ]; then
            agenix -r "$FLAKE_ROOT/secrets/secrets.nix" --decrypt "$FLAKE_ROOT/secrets/tailscale/authkey.age" > "$SECRETS_DIR/ts.key"
          else
            echo "Warning: no Tailscale key found at secrets/tailscale/authkey.age"
            echo "Creating placeholder..."
            echo "PLACEHOLDER" > "$SECRETS_DIR/ts.key"
          fi

          echo "-> Copying SSH authorized key..."
          echo "${config.me.sshKey}" > "$SECRETS_DIR/authorized_keys"

          echo "-> Generating ephemeral SSH host key..."
          ssh-keygen -t ed25519 -f "$SECRETS_DIR/ssh_host_ed25519_key" -N "" -q

          echo "-> Building installer ISO..."
          nix build "path:$FLAKE_ROOT#installer-iso" --out-link "$ISO_DIR/result-iso" --no-link

          ISO_FILE=$(find "$ISO_DIR/result-iso" -name "*.iso" -type f 2>/dev/null | head -1)
          if [ -n "$ISO_FILE" ]; then
            cp "$ISO_FILE" "$ISO_DIR/nixos-installer.iso"
            echo "-> ISO built: $ISO_DIR/nixos-installer.iso"
          else
            echo "Error: no ISO file found in build result"
            exit 1
          fi
        '';
      };
    };
  };
}
