{ config, lib, flake, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./configuration.nix
    flake.inputs.self.nixosModules.common
  ];

  nixpkgs.hostPlatform = "x86_64-linux";
  system.stateVersion = "26.05";
  networking.hostName = "desktop";
  nixos-unified.sshTarget = "seanc@desktop";

  # ── System Profiles ──────────────────────────────────────────────────────
  my.profiles = {
    workstation.enable = true;
    development.enable = true;
    desktop.gnome.enable = true;
    gpu.mesa.enable = true;
    location.enable = true;
  };

  my.homeProfiles = {
    common.enable = true;
    desktop.enable = true;
    development.enable = true;
  };

  # ── Location ────────────────────────────────────────────────────────────
  my.system.location = {
    timeZone = "GB";
    latitude = 55.8617;
    longitude = -4.2583;
  };

  # ── Dual-Boot Partition Layout ──────────────────────────────────────────
  my.disko.dualBoot = {
    enable = false;
    disk = "/dev/nvme0n1";
    espSizeGB = 1;
    windowsSizeGB = 150;
  };

  # ── DSC v3 YAML Generation (Nix→Windows managed config) ─────────────────
  # Auto-derives hostname, timezone, dark mode from NixOS config.
  # Adds aggressive Windows Update control + telemetry reduction.
  my.services.dscnix = {
    enable = false;
    configurationName = "DesktopWindowsDSC";

    # ── Gaming-only Windows: aggressive update management ────────────────
    registry = {
      # Disable Cortana entirely
      "DisableCortana" = {
        keyPath = "HKLM\\SOFTWARE\\Policies\\Microsoft\\Windows\\Windows Search";
        valueName = "AllowCortana";
        valueData = { DWord = 0; };
      };
      # Disable Bing search in Start menu
      "DisableBingSearch" = {
        keyPath = "HKLM\\SOFTWARE\\Policies\\Microsoft\\Windows\\Explorer";
        valueName = "DisableSearchBoxSuggestions";
        valueData = { DWord = 1; };
      };
      # No auto-reboot when users are logged in
      "NoAutoRebootWithLoggedOnUsers" = {
        keyPath = "HKLM\\SOFTWARE\\Policies\\Microsoft\\Windows\\WindowsUpdate\\AU";
        valueName = "NoAutoRebootWithLoggedOnUsers";
        valueData = { DWord = 1; };
      };
      # Download updates but let user choose when to install
      "AUOptions" = {
        keyPath = "HKLM\\SOFTWARE\\Policies\\Microsoft\\Windows\\WindowsUpdate\\AU";
        valueName = "AUOptions";
        valueData = { DWord = 3; };
      };
      # Defer feature updates by 365 days
      "DeferFeatureUpdates" = {
        keyPath = "HKLM\\SOFTWARE\\Policies\\Microsoft\\Windows\\WindowsUpdate";
        valueName = "DeferFeatureUpdates";
        valueData = { DWord = 1; };
      };
      "DeferFeatureUpdatesPeriodInDays" = {
        keyPath = "HKLM\\SOFTWARE\\Policies\\Microsoft\\Windows\\WindowsUpdate";
        valueName = "DeferFeatureUpdatesPeriodInDays";
        valueData = { DWord = 365; };
      };
      # Do not include drivers with Windows Update
      "ExcludeWUDriversInQualityUpdate" = {
        keyPath = "HKLM\\SOFTWARE\\Policies\\Microsoft\\Windows\\WindowsUpdate";
        valueName = "ExcludeWUDriversInQualityUpdate";
        valueData = { DWord = 1; };
      };
      # Disable Delivery Optimization (peer-to-peer updates)
      "DisableDeliveryOptimization" = {
        keyPath = "HKLM\\SOFTWARE\\Policies\\Microsoft\\Windows\\DeliveryOptimization";
        valueName = "DODownloadMode";
        valueData = { DWord = 0; };
      };
      # Telemetry: Basic (1) instead of Full (3)
      "AllowTelemetry" = {
        keyPath = "HKLM\\SOFTWARE\\Policies\\Microsoft\\Windows\\DataCollection";
        valueName = "AllowTelemetry";
        valueData = { DWord = 1; };
      };
      # Disable tailored experiences (advertising ID)
      "DisableTailoredExperiences" = {
        keyPath = "HKLM\\SOFTWARE\\Policies\\Microsoft\\Windows\\DataCollection";
        valueName = "AllowTailoredExperiencesWithDiagnosticData";
        valueData = { DWord = 0; };
      };
    };

    # WSL for when you need Linux on Windows
    optionalFeatures = {
      "Microsoft-Windows-Subsystem-Linux" = { state = "Installed"; };
      "VirtualMachinePlatform" = { state = "Installed"; };
    };

    # Post-install cleanup commands (applied by DSC on every run)
    runCommands = {
      "RemoveBingBloat" = {
        executable = "powershell.exe";
        arguments = [ "-NoProfile" "-Command" "Get-AppxPackage *bing* | Remove-AppxPackage" ];
      };
    };
  };

  # ── Windows Installer ────────────────────────────────────────────────────
  # Creates a Windows 11 Pro unattended ISO on first boot.
  # Password is read from agenix — create before install:
  #   agenix -e secrets/windows-password.age
  my.services.windowsInstaller = {
    enable = false;
    windowsDisk = "/dev/nvme0n1";
    localUsername = "seanc";
    computerName = "desktop";
    localPasswordFile = if config.age.secrets ? "windows-password"
      then config.age.secrets.windows-password.path
      else null;
    dscConfigPath = "${config.my.services.dscnix.configFile}";
  };

  # ── Post-Install: Restore GRUB boot order after Windows Setup ────────────
  my.services.windowsPostInstall = {
    enable = false;
    autoFixBootOrder = true;
  };

  # ── Ongoing DSC Sync: Push config to Windows on every NixOS rebuild ─────
  my.services.windowsDscSync = {
    enable = false;
    windowsPartition = "/dev/disk/by-partlabel/Windows";
  };

  # ── VM Testing ─────────────────────────────────────────────────────────
  my.testing.vmTest.enable = true;

  # ── Additional Programs ────────────────────────────────────────────────
  my.programs.spotify.enable = true;

  # ── Home Manager Extra ───────────────────────────────────────────────────
  my.homeManager.extraConfig = {
    my.programs = {
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

    my.services.kanshi = {
      enable = true;
      settings = [
        {
          profile = {
            name = "desk";
            outputs = [
              # Left — vertical
              {
                criteria = "DP-2";
                status = "enable";
                position = "0,0";
                mode = "1920x1200@59.88Hz";
                scale = 1.0;
                transform = "90";
              }
              # Center — horizontal (1440p)
              {
                criteria = "DP-1";
                status = "enable";
                position = "1200,0";
                mode = "2560x1440@59.91Hz";
                scale = 1.0;
              }
              # Right — vertical
              {
                criteria = "DP-3";
                status = "enable";
                position = "3760,0";
                mode = "1920x1200@59.88Hz";
                scale = 1.0;
                transform = "270";
              }
            ];
          };
        }
      ];
    };
  };
}
