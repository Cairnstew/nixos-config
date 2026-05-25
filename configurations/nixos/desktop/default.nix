# Desktop Configuration
# AMD-based desktop PC with dual-boot (NixOS + Windows 11)
# See: ../../AGENT.md for configuration conventions
{ config, flake, ... }:
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
    disk = "/dev/nvme0n1"; # TODO: Change to your actual disk device
    espSizeGB = 1; # 1GB EFI System Partition
    windowsSizeGB = 150; # 150GB for Windows 11
    # nixosSizeGB = null;   # null = use remaining space
  };

  # ── DSC v3 YAML Generation (semi-managed Windows config) ─────────────────
  # Generates a DSC v3 YAML file at /etc/dscnix/desktop.yaml with values
  # auto-derived from this host config (hostname, dark mode, timezone).
  # Add host-specific Windows configuration below.
  my.services.dscnix = {
    enable = true;
    configurationName = "DesktopWindowsDSC";

    # Auto-derive is enabled by default (hostname, darkMode, timezone).
    # Add host-specific extras:
    optionalFeatures = {
      "Microsoft-Windows-Subsystem-Linux" = { state = "Installed"; };
      "VirtualMachinePlatform" = { state = "Installed"; };
    };

    # Desktop-appropriate registry tweaks
    registry = {
      "DisableCortana" = {
        keyPath = "HKLM\\SOFTWARE\\Policies\\Microsoft\\Windows\\Windows Search";
        valueName = "AllowCortana";
        valueData = { DWord = 0; };
      };
      "DisableBingSearch" = {
        keyPath = "HKLM\\SOFTWARE\\Policies\\Microsoft\\Windows\\Explorer";
        valueName = "DisableSearchBoxSuggestions";
        valueData = { DWord = 1; };
      };
    };

    # First-boot bloatware removal
    runCommands = {
      "RemoveBingBloat" = {
        executable = "powershell.exe";
        arguments = [ "-NoProfile" "-Command" "Get-AppxPackage *bing* | Remove-AppxPackage" ];
      };
    };
  };

  # ── Windows Installer ────────────────────────────────────────────────────
  # TODO: Set localPassword via agenix secret or config.nix
  # DO NOT commit plaintext passwords to the repository!
  my.services.windowsInstaller = {
    enable = true;
    windowsDisk = "/dev/nvme0n1"; # TODO: Change to match disko disk
    localUsername = "user"; # TODO: Change to your preferred username
    # localPassword = builtins.readFile config.age.secrets.windows-password.path;

    # dscConfigPath is a build-time Nix store path; interpolated at eval time.
    # Resolves to /nix/store/...-dscnix-desktop.yaml.
    # Runtime symlink at /etc/dscnix/desktop.yaml is created by the dscnix module.
    dscConfigPath = "${config.my.services.dscnix.configFile}";
  };

  # ── Service Configuration ────────────────────────────────────────────────
  # Update these interfaces for your desktop's network configuration
  # my.services.natShare = {
  #   enable = true;
  #   wanInterface = "eth0";
  #   lanInterface = "eth1";
  # };

  # ── VM Testing ─────────────────────────────────────────────────────────
  my.testing.vmTest.enable = true;

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
