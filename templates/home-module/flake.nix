{
  description = "Home Manager Module";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ self, flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" "x86_64-darwin" ];

      flake.homeModules.default = { config, lib, pkgs, ... }: {
        options.my.programs.my-program = {
          enable = lib.mkEnableOption "My Program";
        };

        config = lib.mkIf config.my.programs.my-program.enable {
          home.packages = [ pkgs.hello ];
        };
      };

      perSystem = { config, self', inputs', pkgs, system, ... }: {
        devShells.default = pkgs.mkShell {
          packages = with pkgs; [ ];
        };
      };
    };
}
