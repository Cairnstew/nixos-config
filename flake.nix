{
  description = "Srid's NixOS / nix-darwin configuration";

  inputs = {
      flake-parts.url = "github:hercules-ci/flake-parts";
  
      # Principle inputs
  
      # RETARDED POLITICAL UPSTREAM BREAKS CACHE OFTEN
      nixpkgs.url = "github:nixos/nixpkgs/6b5a23a12dfcf90e4ebc041925d63668314a39fc";
  
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
      # Software inputs
      github-nix-ci.url = "github:juspay/github-nix-ci";
      nixos-vscode-server.flake = false;
      nixos-vscode-server.url = "github:nix-community/nixos-vscode-server";
      nix-vscode-extensions.url = "github:nix-community/nix-vscode-extensions/fd5c5549692ff4d2dbee1ab7eea19adc2f97baeb";
      
      #nix-index-database.url = "github:nix-community/nix-index-database";
      #nix-index-database.inputs.nixpkgs.follows = "nixpkgs";
      #try.url = "github:tobi/try";
      #vira.url = "github:juspay/vira";
      #nix-ai-tools.url = "github:numtide/nix-ai-tools";
      #nix-ai-tools.inputs.nixpkgs.follows = "nixpkgs";
      #landrun-nix.url = "github:srid/landrun-nix";
  
      # Neovim
      #nixvim.url = "github:nix-community/nixvim";
      #nixvim.inputs.nixpkgs.follows = "nixpkgs";
      # Emacs
      #nix-doom-emacs-unstraightened.url = "github:marienz/nix-doom-emacs-unstraightened";
      #nix-doom-emacs-unstraightened.inputs.nixpkgs.follows = "nixpkgs";
  
      # Devshell
      git-hooks.url = "github:cachix/git-hooks.nix";
      git-hooks.flake = false;
    };

  # Wired using https://nixos-unified.org/autowiring.html
    outputs = inputs:
      inputs.nixos-unified.lib.mkFlake
        { inherit inputs; root = ./.; };
  }
