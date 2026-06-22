{
  description = "tModLoader Mod Development Environment";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs = inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" "x86_64-darwin" ];

      perSystem = { pkgs, ... }: {
        devShells.default = pkgs.mkShell {
          name = "tmodloader-mod-dev";

          packages = with pkgs; [
            dotnet-sdk_8
            git
          ];

          shellHook = ''
            echo ""
            echo "  ╔══════════════════════════════════════════════╗"
            echo "  ║     tModLoader Mod Development Shell         ║"
            echo "  ╚══════════════════════════════════════════════╝"
            echo ""
            echo "  .NET SDK: $(dotnet --version)"
            echo "  OS:       $(uname -s -m)"
            echo ""
            echo "  ── Quick Start ──"
            echo "  Edit build.txt, description.txt, then start coding"
            echo ""
            echo "  ── Building your mod ──"
            echo "  Place this project in tModLoader's ModSources dir:"
            echo "    Linux:   ~/.local/share/Terraria/tModLoader/ModSources/"
            echo "    macOS:   ~/Library/Application Support/Terraria/tModLoader/ModSources/"
            echo "    Windows: Documents/My Games/Terraria/tModLoader/ModSources/"
            echo ""
            echo "  Then run: dotnet build (from inside ModSources/YourMod)"
            echo ""
          '';
        };
      };
    };
}
