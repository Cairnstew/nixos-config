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
    nm.default-build
  
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
  my = { 
    secrets.enable = lib.mkDefault true;
    system = {
      audio.enable = true;
      bluetooth.enable = true;
      location.enable = true;
    };
    services = {
      ssh.enable = true;
      tailscale = {
        enable            = lib.mkDefault true;
        tags              = lib.mkDefault [ "tag:nixos" ];
        ssh = {
          enable           = lib.mkDefault true;
          user             = lib.mkDefault flake.config.me.username;
          extraHostConfig  = lib.mkDefault "ForwardAgent yes";
          publicKeyPath = (flake.inputs.self + /secrets/tailscale-ssh-key.pub);
        };
      };
      cachix-push = {
        enable = config.age.secrets ? "nixos-config-cache-token";
        cacheName = "cairnstew-nixos-config-cache";
        tokenFile = config.age.secrets.nixos-config-cache-token.path;
      };
      gitRepoSync = {
        enable = true;
        user = flake.config.me.username;
        repos = {
          nix-config = {
            url              = "https://github.com/Cairnstew/nixos-config.git";
            path             = "/home/${flake.config.me.username}/nixos-config";
            interval         = "1m";
            conflictStrategy = "ff-only";
            branches = [ "master" ];
            agenix = {
              enable     = config.age.secrets ? "github-token-nixos-config";
              secretPath = config.age.secrets.github-token-nixos-config.path;
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
