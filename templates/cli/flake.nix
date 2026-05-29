{
  description = "CLI Tool";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs = inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" "x86_64-darwin" ];

      perSystem = { config, self', inputs', pkgs, system, ... }: {
        packages.default = pkgs.writeShellScriptBin "my-cli" ''
          #!/usr/bin/env bash
          set -euo pipefail

          usage() {
            echo " Usage: my-cli [ command ] [ options ] "
            echo " "
            echo " Commands: "
            echo " hello
          Print
          hello
          message "
            echo "
          help
          Show
          this
          help "
}

          case " ''${1:-}" in
            hello)
              echo "Hello, world!"
              ;;
            help|--help|-h|"")
              usage
              ;;
            *)
              echo "Unknown command: $1"
              usage
              exit 1
              ;;
          esac
        '';

        apps.default = {
          type = "app";
          program = "''${self'.packages.default}/bin/my-cli";
        };

        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            shellcheck
            shfmt
          ];
        };
      };
    };
}



