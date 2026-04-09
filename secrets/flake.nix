{
  description = "Dev shell with agenix + 1Password helper";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, agenix, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };
      in {
        devShells.default = pkgs.mkShell {
          packages = [
            agenix.packages.${system}.default
            pkgs._1password-cli
          ];

          shellHook = ''
            export EDITOR=nano
            export PRIVATE_KEY=/etc/ssh/ssh_host_ed25519_key
            export RULES=./secrets.nix

            agenix-rekey() {
              set -euo pipefail

              if ! op account list &>/dev/null || [ -z "$(op account list)" ]; then
                echo "No 1Password accounts configured, adding one..."
                op account add
              fi

              if ! op account get &>/dev/null; then
                eval "$(op signin)"
              fi

              TMPKEY=$(mktemp)
              trap "rm -f $TMPKEY" EXIT

              op read "op://Private/Nixos/private key" > "$TMPKEY"
              chmod 600 "$TMPKEY"

              nix run github:ryantm/agenix -- -r -i "$TMPKEY"
            }

            echo "Available commands:"
            echo "  agenix-rekey  → rekey secrets using 1Password"
          '';
        };
      }
    );
}