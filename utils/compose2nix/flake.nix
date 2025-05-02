{
  description = "A flake that runs compose2nix with multiple compose files";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    compose2nix.url = "github:aksiksi/compose2nix";
  };

  outputs = { self, nixpkgs, compose2nix, ... }@inputs:
    let
      pkgs = import nixpkgs { system = "x86_64-linux"; };
      compose2nixPkg = compose2nix.packages.x86_64-linux.default;
      compose-files = [
        # Add more files here
      ];
      
      compose-files-str = builtins.concatStringsSep "," (builtins.map (path: toString path) compose-files);
    in
    {
      packages.x86_64-linux.default = pkgs.writeShellApplication {
        name = "run-compose2nix";
        runtimeInputs = [ compose2nixPkg ];
        text = ''
          set -e

          echo "Running compose2nix with inputs: ${compose-files-str}"

          compose2nix \
            -inputs="${compose-files-str}" \
            -project="home-manager" \
            -runtime="docker" \
            -output="/etc/nixos/apps/imports/docker-containers.nix"
        '';
      };

      apps.x86_64-linux.default = {
        type = "app";
        program = "${self.packages.x86_64-linux.default}/bin/run-compose2nix";
      };
    };
}
