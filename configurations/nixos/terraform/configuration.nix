{ config, pkgs, ... }:

{
  # Minimal boot and networking
  boot.loader.grub.device = "/dev/xvda"; 
  networking.hostName = "nixos-vm";
  
  # REQUIRED: Allow SSH access for the terraform-nixos module
  services.openssh.enable = true;
  
  # Basic system packages
  environment.systemPackages = with pkgs; [
    vim
    git
    htop
  ];

  system.stateVersion = "23.11"; # Match your nixpkgs version
}