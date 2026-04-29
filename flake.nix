{
  description = "Srid's NixOS / nix-darwin configuration";

  nixConfig = {
    substituters = [
      "https://cache.nixos-cuda.org/"
      "https://cache.nixos.org/"
      "https://nix-community.cachix.org"
    
    ];
    trusted-public-keys = [
      "cache.nixos-cuda.org-1:dykfIgNYfi2cKCfb4xMBbOjlzFnEiCsHxlXLjfXDwOY="
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
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
        inputs.nixpkgs.follows = "nixpkgs";   # important to avoid version mismatch
      };

      terranix = {
        url = "github:terranix/terranix";
        inputs.nixpkgs.follows = "nixpkgs";
      };

      # Software inputs
      github-nix-ci.url = "github:juspay/github-nix-ci";
      nixos-vscode-server.flake = false;
      nixos-vscode-server.url = "github:nix-community/nixos-vscode-server";
      flake-utils.url = "github:numtide/flake-utils";
      nix-index-database.url = "github:nix-community/nix-index-database";
      nix-index-database.inputs.nixpkgs.follows = "nixpkgs";
      try.url = "github:tobi/try";
      vira.url = "github:juspay/vira";
      nix-ai-tools.url = "github:numtide/nix-ai-tools";
      nix-ai-tools.inputs.nixpkgs.follows = "nixpkgs";
      landrun-nix.url = "github:srid/landrun-nix";
	    hyprland.url = "github:hyprwm/Hyprland";
      compose2nix.url = "github:aksiksi/compose2nix";
      compose2nix.inputs.nixpkgs.follows = "nixpkgs";   
	  	
      # Neovim
      nixvim.url = "github:nix-community/nixvim";
      nixvim.inputs.nixpkgs.follows = "nixpkgs";
      # Emacs
      nix-doom-emacs-unstraightened.url = "github:marienz/nix-doom-emacs-unstraightened";
      nix-doom-emacs-unstraightened.inputs.nixpkgs.follows = "nixpkgs";

      zig-overlay.url = "github:mitchellh/zig-overlay";
      
      # Terminal
      ghostty = {
        url = "github:ghostty-org/ghostty/v1.2.3";
        inputs = {
          nixpkgs.follows = "nixpkgs";
          zig.follows = "zig-overlay";
        };
      };

      # Devshell
      git-hooks.url = "github:cachix/git-hooks.nix";
      git-hooks.flake = false;
    };

  # Wired using https://nixos-unified.org/autowiring.html
    outputs = inputs@{ self, ... }:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" ];
      imports = (with builtins;
        map
          (fn: ./modules/flake-parts/${fn})
          (attrNames (readDir ./modules/flake-parts)));

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
    };
}
