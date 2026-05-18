# modules/nixos/common.nix
# Common configuration imported by ALL NixOS hosts
# This is the single entry point for shared system configuration
{ flake, lib, config, ... }:
let
  inherit (flake) inputs;
  inherit (inputs) self;
  
  # Helper to check if this is a WSL system
  isWSL = config.wsl.enable or false;
in
{
  imports = [
    # ── Core System ────────────────────────────────────────────────────────
    ./nix.nix
    ./primary-as-admin.nix
    ./self-ide.nix
    ./_1password
    
    # ── Hardware ───────────────────────────────────────────────────────────
    ./audio.nix
    ./battery.nix
    ./bluetooth.nix
    ./graphics.nix
    
    # ── Desktop ────────────────────────────────────────────────────────────
    ./gnome
    ./plasma-x11.nix
    
    # ── Virtualization ─────────────────────────────────────────────────────
    ./docker.nix
    ./waydroid.nix
    ./ollama
    
    # ── Networking ─────────────────────────────────────────────────────────
    ./ssh.nix
    ./tailscale
    ./natShare.nix
    ./nebula.nix
    ./rustdesk.nix
    
    # ── Utilities ───────────────────────────────────────────────────────────
    ./brasero.nix
    ./udisks2.nix
    ./ventoy.nix
    ./gitreposync
    ./cachix-push.nix
    ./default-build.nix
    
    # ── Entertainment ──────────────────────────────────────────────────────
    ./spotify.nix
    ./sillytavern
    
    # ── Location & Secrets ────────────────────────────────────────────────
    ./current-location.nix
    ./secrets
    
    # ── Profiles System ────────────────────────────────────────────────────
    ./profiles
    
    # ── Home Manager Integration ───────────────────────────────────────────
    ./homeManager
    
    # ── External Modules ───────────────────────────────────────────────────
    inputs.agenix.nixosModules.default
    inputs.nixos-wsl.nixosModules.default
  ];

  # ── Base System Configuration ────────────────────────────────────────────
  
  # User setup
  users.users.${flake.config.me.username} = {
    isNormalUser = lib.mkDefault true;
    extraGroups = lib.mkDefault [ "terraform" "docker" "wheel" ];
  };

  # ── Sensible Defaults ────────────────────────────────────────────────────
  
  my = {
    # Secrets enabled by default (safe to have, won't fail if keys missing)
    secrets.enable = lib.mkDefault true;
    
    # SSH always available for remote management
    services.ssh.enable = lib.mkDefault true;
    
    # Tailscale for VPN/mesh networking
    services.tailscale = {
      enable = lib.mkDefault true;
      tags = lib.mkDefault [ "tag:nixos" ];
      ssh = {
        enable = lib.mkDefault true;
        user = lib.mkDefault flake.config.me.username;
        extraHostConfig = lib.mkDefault "ForwardAgent yes";
      };
    };
    
    # Git repo sync for this config
    services.gitRepoSync = {
      enable = lib.mkDefault true;
      user = lib.mkDefault flake.config.me.username;
      repos.nix-config = {
        url = lib.mkDefault "https://github.com/Cairnstew/nixos-config.git";
        path = lib.mkDefault "/home/${flake.config.me.username}/nixos-config";
        interval = lib.mkDefault "5m";
        conflictStrategy = lib.mkDefault "ff-only";
      };
    };
  };

  # ── Boot Configuration ───────────────────────────────────────────────────
  # Note: Bootloader configuration (grub/systemd-boot) is host-specific
  # and should be configured in the host's configuration.nix
  # This prevents grub from being implicitly enabled
  boot.loader.grub.enable = lib.mkDefault false;

  # ── Environment ──────────────────────────────────────────────────────────
  # Packages are defined per-host or use environment.systemPackages directly

  # ── Assertions ───────────────────────────────────────────────────────────
  assertions = [
    {
      assertion = 
        !(config.my.profiles.gpu.mesa.enable or false) || 
        !(config.my.profiles.gpu.nvidia.enable or false);
      message = "Cannot enable both Mesa and NVIDIA GPU profiles.";
    }
  ];
}
