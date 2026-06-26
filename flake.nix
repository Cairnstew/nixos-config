{
  description = "Srid's NixOS / nix-darwin configuration";

  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";

    # Principle inputs

    # RETARDED POLITICAL UPSTREAM BREAKS CACHE OFTEN
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";


    nix-darwin.url = "github:LnL7/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    stylix.url = "github:nix-community/stylix";
    stylix.inputs.nixpkgs.follows = "nixpkgs";
    nixos-hardware.url = "github:NixOS/nixos-hardware";
    nixos-unified.url = "github:srid/nixos-unified";
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
    agenix.url = "github:ryantm/agenix";
    agenix-manager.url = "github:Cairnstew/agenix-manager";
    agenix-manager.inputs.nixpkgs.follows = "nixpkgs";
    agenix-manager.inputs.agenix.follows = "agenix";
    nuenv.url = "github:hallettj/nuenv/writeShellApplication";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixos-wsl.url = "github:nix-community/NixOS-WSL/main";
    nixos-wsl.inputs.nixpkgs.follows = "nixpkgs";

    nixos-anywhere = {
      url = "github:nix-community/nixos-anywhere";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    auto-cpufreq = {
      url = "github:AdnanHodzic/auto-cpufreq";
      inputs.nixpkgs.follows = "nixpkgs"; # important to avoid version mismatch
    };

    terranix = {
      url = "github:terranix/terranix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Software inputs
    nixos-vscode-server.flake = false;
    nixos-vscode-server.url = "github:nix-community/nixos-vscode-server";

    # ISOS

    # Pre-built Windows ISOs from GitHub releases
    windows-iso-src = {
      url = "github:Cairnstew/uup-dump-build-and-get-windows-iso";
      flake = true;
    };

    gparted-iso = {
      url = "https://downloads.sourceforge.net/gparted/gparted-live-1.6.0-1-amd64.iso?sha256=18v0w9pcdyqx69w82paadgcniii2zcm52rn2h3fhasp7nr0pdims";
      flake = false;
    };

    # Windows unattended answer file generator
    GenerateAnswerFile = {
      url = "github:Cairnstew/GenerateAnswerFile";
    };

    # DSC v3 YAML configuration generation (Nix → Windows DSC)
    dscnix = {
      url = "github:Cairnstew/dscnix";
      inputs.nixpkgs.follows = "nixpkgs";
    };



    zig-overlay.url = "github:mitchellh/zig-overlay";

    # Terminal
    ghostty = {
      url = "github:ghostty-org/ghostty/v1.2.3";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        zig.follows = "zig-overlay";
      };
    };

    # Tailscale auth key management via Terraform
    tailscale-manager = {
      url = "github:Cairnstew/tailscale-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # MCP server framework — declarative server configs, multi-flavor output
    mcp-servers-nix = {
      url = "github:natsukium/mcp-servers-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Kernel-level mouse acceleration (Wayland-compatible)
    maccel.url = "github:Gnarus-G/maccel";

    # Moku — Tauri manga reader frontend for Suwayomi-Server
    moku = {
      url = "github:moku-project/Moku";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # SillyTavern LLM frontend — upstream module with declarative presets
    sillytavern = {
      url = "github:Cairnstew/SillyTavern";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Houdini — FHS-wrapped 3D animation package (manual download required)
    houdini-nix = {
      url = "github:permahorse/houdini-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Nixtest — Nix code test runner (unit, snapshot, script, VM)
    nixtest = {
      url = "gitlab:TECHNOFAB/nixtest";
      inputs.nixpkgs.follows = "nixpkgs";
    };

  };

  # Wired using https://nixos-unified.org/autowiring.html
  outputs = inputs@{ self, ... }:
    inputs.flake-parts.lib.mkFlake { inherit inputs; }
      ({ config, lib, ... }: {
        systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" ];
        imports =
          let
            entries = builtins.readDir ./modules/flake-parts;
            names = builtins.attrNames entries;

            # All .nix files at the top level (existing behaviour)
            nixFiles = builtins.filter (fn: builtins.match ".*\\.nix" fn != null) names;
            flatImports = builtins.map (fn: ./modules/flake-parts/${fn}) nixFiles;

            # Subdirectories containing default.nix (like autowiring)
            dirs = builtins.filter (name: entries.${name} == "directory") names;
            dirImports = builtins.filter (p: p != null) (builtins.map
              (name:
                let p = ./modules/flake-parts/${name}/default.nix;
                in if builtins.pathExists p then p else null
              )
              dirs);
          in
          flatImports ++ dirImports;


        perSystem = { lib, system, ... }: {
          # Make our overlay available to the devShell
          # "Flake parts does not yet come with an endorsed module that initializes the pkgs argument.""
          # So we must do this manually; https://flake.parts/overlays#consuming-an-overlay
          _module.args.pkgs = import inputs.nixpkgs {
            inherit system;
            overlays = lib.attrValues self.overlays;
            config.allowUnfree = true;
          };
        };
      });
}
 
