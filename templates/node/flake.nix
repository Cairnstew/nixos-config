{
  description = "Node.js Project";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs = inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" "x86_64-darwin" ];

      perSystem = { config, self', inputs', pkgs, system, ... }: {
        packages.default = pkgs.buildNpmPackage {
          pname = "my-node-project";
          version = "0.1.0";
          src = ./.;
          npmDepsHash = ""; # Set to pkgs.lib.fakeSha256 to get the actual hash
        };

        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            nodejs
            pnpm
          ];
        };
      };
    };
}
