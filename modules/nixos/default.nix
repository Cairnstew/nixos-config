# Configuration common to all Linux systems
{ flake, lib, config, pkgs, ... }:

let
  inherit (flake) inputs;
  inherit (inputs) self;


  # Shorthand for nixosModules
  nm = self.nixosModules;

  # Shorthand for external nixosModules from inputs
  agenixModules = inputs.agenix.nixosModules.default;
in
{
  imports = [

    # Static configuration
    nm.nix
    nm.primary-as-admin
    nm.self-ide
    nm._1password
    
    # Common
    nm.current-location
    nm.ssh
    
    # Home Manager
    nm.homeManager

    # Linux Specific
    nm.audio
    nm.battery
    nm.bluetooth

    # Graphics
    nm.graphics
    nm.gpu-amd
    nm.gpu-nvidia
    nm.gpu-mesa
    nm.vulkan

    # Desktop Environments
    nm.gnome
    nm.plasma-x11

    # Containers & Virtualization
    nm.docker
    nm.waydroid

    # Utility
    nm.brasero
    nm.udisks2
    nm.ventoy
    nm.uup-converter
    nm.gitreposync
    nm.cachix-push
  
    # Entertainment
    nm.spotify

    # Networking
    nm.rustdesk
    nm.natShare
    nm.nebula
    nm.tailscale

    # External modules
    agenixModules
  ];

  environment.systemPackages = [
    pkgs.dig
  ];

  age.secrets = {
      "github-token" = {
        file = flake.inputs.self + /secrets/github-token.age;
        owner = "${flake.config.me.username}";
        mode = "0400";
        group = "users";
        };
      "obsidian-git-token" = {
        file = flake.inputs.self + /secrets/obsidian-git-token.age;
        owner = "${flake.config.me.username}";
        mode = "0400";
      };
      "nixos-config-git-token" = {
        file = flake.inputs.self + /secrets/nixos-config-git-token.age;
        owner = "${flake.config.me.username}";
        mode = "0400";
      };
      "nixos-config-cache-token" = {
        file = flake.inputs.self + /secrets/nixos-config-cache-token.age;
        owner = "root";
        mode = "0400";
      };
    };
  my = { 
    system = {
      audio.enable = true;
      bluetooth.enable = true;
      location.enable = true;
    };
    services = {
      ssh.enable = true;
      tailscale = {
        enable            = lib.mkDefault true;
        authKeySecretFile = lib.mkDefault (flake.inputs.self + /secrets/tailscale-authkey.age);
        tags              = lib.mkDefault [ "tag:nixos" ];
        ssh = {
          enable           = lib.mkDefault true;
          user             = lib.mkDefault flake.config.me.username;
          apiKeySecretFile  = lib.mkDefault (flake.inputs.self + /secrets/tailscale-apikey.age);
          sshKeySecretFile = lib.mkDefault (flake.inputs.self + /secrets/tailscale-ssh-key.age);
          sshPublicKeyFile = lib.mkDefault (flake.inputs.self + /secrets/tailscale_id.pub);
          extraHostConfig  = lib.mkDefault "ForwardAgent yes";
        };
      };
      cachix-push = {
        enable = true;
        cacheName = "cairnstew-nixos-config-cache";
        tokenFile = config.age.secrets.nixos-config-cache-token.path;
      };
      gitRepoSync = {
        enable = true;
        repos = {
          nix-config = {
            url              = "https://github.com/Cairnstew/nixos-config.git";
            path             = "/home/${flake.config.me.username}/nixos-config";
            interval         = "10m";
            conflictStrategy = "ff-only";
            agenix = {
              enable     = true;
              secretPath = config.age.secrets.nixos-config-git-token.path;
            };
          };
        };
      };
    };
  };

  assertions = [
    {
      assertion =
        !(config.hardwareProfiles.gpu.mesa.enable
          && config.hardwareProfiles.gpu.nvidia.enable);
      message = "Enable only one GPU profile (mesa OR nvidia).";
    }
  ];

  boot.loader.grub.configurationLimit = 5; # Who needs more?
}
