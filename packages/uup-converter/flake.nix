{
  description = "UUP API";
inputs.nixpkgs.url = "github:NixOS/nixpkgs";
outputs = { self, nixpkgs }:
let
systems = [ "x86_64-linux" "aarch64-linux" ];
forAllSystems = nixpkgs.lib.genAttrs systems;
in {
packages = forAllSystems (system:
let
pkgs = import nixpkgs { inherit system; };
in {
uup-converter = pkgs.callPackage ./default.nix {};
default = self.packages.${system}.uup-api
      }
    );
  };
}