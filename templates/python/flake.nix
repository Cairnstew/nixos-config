{
  description = "Python Project";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs = inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" "x86_64-darwin" ];

      perSystem = { config, self', inputs', pkgs, system, ... }: {
        packages.default = pkgs.stdenv.mkDerivation {
          pname = "my-project";
          version = "0.1.0";
          src = ./.;
          nativeBuildInputs = with pkgs; [ makeWrapper ];
          buildInputs = with pkgs; [ python3 ];
          installPhase = ''
            mkdir -p $out/bin
            cp -r src $out/lib
            makeWrapper ${pkgs.python3}/bin/python $out/bin/my-project \
              --add-flags "$out/lib/main.py"
          '';
        };

        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            python3
            uv
            ruff
            mypy
            python3Packages.pytest
          ];
          shellHook = ''
            echo "Python project with uv"
            echo "Run 'uv init' to initialize pyproject.toml"
          '';
        };
      };
    };
}
