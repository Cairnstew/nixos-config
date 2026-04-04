{
  description = "OpenTofu dev environment with direnv";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";

      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [
          opentofu
          awscli2
          jq
        ];

        shellHook = ''
          echo "OpenTofu dev shell loaded"
        '';
      };
    };
}