{
  description = "Haskell Project";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    haskell-flake.url = "github:srid/haskell-flake";
  };

  outputs = inputs@{ flake-parts, haskell-flake, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" "x86_64-darwin" ];
      imports = [ haskell-flake.flakeModule ];

      perSystem = { config, self', inputs', pkgs, system, ... }: {
        haskellProjects.default = {
          devShell = {
            tools = hp: { inherit (hp) cabal-install haskell-language-server; };
          };
        };
      };
    };
}
