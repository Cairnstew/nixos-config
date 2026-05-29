{
  description = "Srid's NixOS / nix-darwin configuration";

  nixConfig = {
    substituters = [
      "https://cache.nixos-cuda.org/"
      "https://cache.nixos.org/"
      "https://nix-community.cachix.org"
      "https://cairnstew-nixos-config-cache.cachix.org"
    ];

    trusted-public-keys = [
      "cache.nixos-cuda.org-1:dykfIgNYfi2cKCfb4xMBbOjlzFnEiCsHxlXLjfXDwOY="
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="

      # Your cache
      "cairnstew-nixos-config-cache.cachix.org-1:1150paajFeK18p7Eie/4L8iews3pbFbVp3eOxkmXar4="
    ];
  };

  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";

    # Principle inputs

    # RETARDED POLITICAL UPSTREAM BREAKS CACHE OFTEN
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";


    nix-darwin.url = "github:LnL7/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nixos-hardware.url = "github:NixOS/nixos-hardware";
    nixos-unified.url = "github:srid/nixos-unified";
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
    agenix.url = "github:ryantm/agenix";
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


  };

  # Wired using https://nixos-unified.org/autowiring.html
  outputs = inputs@{ self, ... }:
    inputs.flake-parts.lib.mkFlake { inherit inputs; }
    ({ config, lib, ... }: {
      systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" ];
      imports =
        let
          files = builtins.attrNames (builtins.readDir ./modules/flake-parts);
          nixFiles = builtins.filter (fn: builtins.match ".*\\.nix" fn != null) files;
        in
        builtins.map (fn: ./modules/flake-parts/${fn}) nixFiles;


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
 
