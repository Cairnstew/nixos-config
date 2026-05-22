# Desktop Configuration
# AMD-based desktop PC with dual-boot (NixOS + Windows 11)
# See: ../../AGENT.md for configuration conventions
{ flake, ... }:
{
  imports = [
    # Import hardware config FIRST to set hostPlatform
    ./hardware-configuration.nix
    flake.inputs.self.nixosModules.common
  ];

  # Explicitly set hostPlatform to ensure pkgs is available
  nixpkgs.hostPlatform = "x86_64-linux";

  # ── System State ─────────────────────────────────────────────────────────
  system.stateVersion = "26.05";

  # ── System Identity ──────────────────────────────────────────────────────
  networking.hostName = "desktop";
  nixos-unified.sshTarget = "seanc@desktop";

  # ── System Profiles ──────────────────────────────────────────────────────
  my.profiles = {
    # Role
    workstation.enable = true;
    development.enable = true;

    # Desktop
    desktop.gnome.enable = true;

    # Hardware - AMD GPU uses Mesa drivers
    gpu.mesa.enable = true;
    # Note: No battery profile - this is a desktop PC
    location.enable = true;
  };

  # ── Home Profiles ──────────────────────────────────────────────────────
  my.homeProfiles = {
    common.enable = true;
    desktop.enable = true;
    development.enable = true;
  };

  # ── Location ────────────────────────────────────────────────────────────
  my.system.location = {
    timeZone = "GB";
    # Update these coordinates to your location
    latitude = 55.8617;
    longitude = 4.2583;
  };

  # ── Dual-Boot Configuration ─────────────────────────────────────────────
  # TODO: Update this disk device to match your actual hardware
  # Use `lsblk` to find your disk (typically /dev/nvme0n1 for NVMe or /dev/sda for SATA)
  my.disko.dualBoot = {
    enable = true;
    disk = "/dev/nvme0n1";  # TODO: Change to your actual disk device
    windowsSizeGB = 150;     # 150GB for Windows 11
    # nixosSizeGB = null;    # null = use remaining space
  };

  # ── Windows Installer ────────────────────────────────────────────────────
  # TODO: Set localPassword via agenix secret or config.nix
  # DO NOT commit plaintext passwords to the repository!
  my.services.windowsInstaller = {
    enable = true;
    windowsDisk = "/dev/nvme0n1";  # TODO: Change to match disko disk
    localUsername = "user";  # TODO: Change to your preferred username
    # localPassword = builtins.readFile config.age.secrets.windows-password.path;
  };

  # ── Service Configuration ────────────────────────────────────────────────
  # Update these interfaces for your desktop's network configuration
  # my.services.natShare = {
  #   enable = true;
  #   wanInterface = "eth0";
  #   lanInterface = "eth1";
  # };

  # ── Additional Programs ────────────────────────────────────────────────
  my.programs.spotify.enable = true;

  # ── Home Manager Extra ───────────────────────────────────────────────────
  my.homeManager.extraConfig.my.programs = {
    discord.enable = true;
    localsend.enable = true;
    firefox.enable = true;
    obsidian.enable = true;
    thunderbird.enable = true;
    vscode.enable = true;
    "whatsapp-electron".enable = true;
    "youtube-music".enable = true;
    thunderbird = {
      email = flake.config.me.email;
      username = flake.config.me.username;
    };
  };
}
