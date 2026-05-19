{
  description = "Nix Library";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs = inputs@{ self, flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" "x86_64-darwin" ];

      flake.lib = import ./lib { inherit (inputs.nixpkgs) lib; };

      perSystem = { config, self', inputs', pkgs, system, ... }: {
        packages.default = pkgs.writeShellScriptBin "my-lib-test" ''
          echo "Library tests would run here"
        '';

        devShells.default = pkgs.mkShell {
          packages = with pkgs; [ ];
        };
      };
    };
}
