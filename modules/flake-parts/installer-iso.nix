{ config, inputs, lib, ... }: {
  perSystem = { pkgs, system, ... }: {
    packages.installer-iso = pkgs.callPackage ../../packages/installer-iso { };

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
          if [ -f "$FLAKE_ROOT/secrets/tailscale/ts-key.age" ]; then
            agenix --decrypt "$FLAKE_ROOT/secrets/tailscale/ts-key.age" > "$SECRETS_DIR/ts.key"
          else
            echo "Warning: no Tailscale key found at secrets/tailscale/ts-key.age"
            echo "Creating placeholder — ISO won't auto-connect to Tailscale."
            echo "PLACEHOLDER" > "$SECRETS_DIR/ts.key"
          fi

          echo "-> Copying SSH authorized key..."
          echo "${config.me.sshKey}" > "$SECRETS_DIR/authorized_keys"

          echo "-> Generating ephemeral SSH host key..."
          ssh-keygen -t ed25519 -f "$SECRETS_DIR/ssh_host_ed25519_key" -N "" -q

          echo "-> Building installer ISO (path-based, includes secrets)..."
          nix build "path:$FLAKE_ROOT#installer-iso" --out-link "$ISO_DIR/result-iso" --no-link

          # Copy the ISO from the build result
          ISO_FILE=$(find "$ISO_DIR/result-iso" -name "*.iso" -type f 2>/dev/null | head -1)
          if [ -n "$ISO_FILE" ]; then
            cp "$ISO_FILE" "$ISO_DIR/nixos-installer.iso"
            echo "-> ISO built: $ISO_DIR/nixos-installer.iso"
          else
            echo "Error: no ISO file found in build result"
            exit 1
          fi

          echo ""
          echo "Done! Place the Ventoy USB at $FLAKE_ROOT/ventoy and run:"
          echo "  cp -r $ISO_DIR/* $FLAKE_ROOT/ventoy/ISO/"
          echo ""
          echo "Or just copy nixos-installer.iso to your Ventoy USB's ISO directory."
        '';
      };
    };
  };
}
