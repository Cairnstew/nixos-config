{ config, lib, pkgs, flake, ... }:
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

  # Always run at performance governor (desktop, always plugged in)
  powerManagement.cpuFreqGovernor = "performance";

  # ── System Profiles ──────────────────────────────────────────────────────
  my.profiles = {
    workstation.enable = true;
    development.enable = true;
    desktop.gnome.enable = true;
    gpu.mesa.enable = true;
    location.enable = true;
    gaming.enable = true;
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

  environment.systemPackages = [ pkgs.gnome-monitor-config ];

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

    systemd.user.services.gnome-monitors = {
      Unit = {
        Description = "Apply GNOME monitor layout";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
      };
      Service = {
        Type = "oneshot";
        ExecStart =
          "/run/current-system/sw/bin/gnome-monitor-config set"
          + " -Lp -t normal -x 1200 -y 0 -M DP-1 -m '2560x1440@179.998'"
          + " -L  -t left   -x 3760 -y 0 -M DP-2 -m '1920x1200@59.950'"
          + " -L  -t right  -x 0    -y 0 -M DP-3 -m '1920x1200@59.950'";
      };
      Install = {
        WantedBy = [ "graphical-session.target" ];
      };
    };
  };
}
