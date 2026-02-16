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
    nm.ssh
    nm.primary-as-admin
    nm.self-ide
    nm._1password

    # Common
    nm.current-location
    
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

    # External modules
    agenixModules
  ];


  my = { 
    system = {
      audio.enable = true;
      battery.enable = true;
      bluetooth.enable = true;
      location.enable = true;
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
