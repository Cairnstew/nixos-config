# Configuration common to all Linux systems
{ flake, lib, config, ... }:

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
  
    # Entertainment
    nm.spotify

    # Networking
    nm.zerotier
    nm.zeronsd
    nm.rustdesk
    nm.natShare

    # External modules
    agenixModules
  ];


  my = { 
    system = {
      audio.enable = true;
      bluetooth.enable = true;
      location.enable = true;
    };
    services = {
      ssh.authorizedKeys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPWrhAp1ZU9p7UvJ1x9ApM1pY9OK2S8crEKHeEAxX0z6 sean.cairnsst@gmail.com" # Laptop
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIrUD7LMeCHW8WP5XGp0STYsp23oWZUWRAk4pjL0xn7f sean.cairnsst@gmail.com" # Server
      ];
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
