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

  # ── Dual-Boot / Partition Layout
  # Windows is on /dev/sda with free space left at the end for NixOS.
  # Expected layout after creating the NixOS partition in free space:
  #   sda1: ESP (vfat, ~100M) — Windows EFI boot
  #   sda2: MSR (16M) — Microsoft Reserved
  #   sda3: Windows (NTFS, C: drive)
  #   sda4: NixOS (ext4, rest) — created before first deploy
  #         (or sda5 if Windows created a recovery partition)
  #
  # First install (two options):
  #
  # Option A — Stock NixOS minimal ISO (simpler, no build step):
  #   1. Boot the NixOS minimal ISO on the desktop
  #   2. Check partition table:
  #        lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINT
  #   3. Format the free space:
  #        sudo mkfs.ext4 -L nixos /dev/sda4   # adjust if sda5 etc.
  #   4. Mount and install:
  #        sudo mount /dev/sda4 /mnt
  #        sudo mkdir -p /mnt/boot && sudo mount /dev/sda1 /mnt/boot
  #        sudo mkdir -p /mnt/etc
  #        git clone https://github.com/Cairnstew/nixos-config /mnt/etc/nixos
  #        sudo nixos-install --flake /mnt/etc/nixos#desktop
  #        sudo reboot
  #
  # Option B — Custom Ventoy ISO (auto-connects to Tailscale, SSH keys baked in):
  #   1. Build the custom ISO:
  #        just ventoy-iso   # produces packages.live-iso-ventoy
  #   2. Deploy to USB:
  #        just ventoy-deploy
  #   3. Or copy ISO + Windows ISO onto a Ventoy USB manually
  #   3. Boot the USB on the desktop
  #   4. It auto-connects to your tailnet — find it via MagicDNS
  #   5. SSH in from your laptop:
  #        ssh root@nixos-installer.tailXXXXX.ts.net
  #   6. Partition and install (same commands as Option A, steps 2-5)
  #
  # After first boot (both options):
  #   just register-host desktop <IP>
  #
  # Future reinstalls (via SSH, no physical access needed):
  #   nix run .#deploy -- desktop root@<IP>
  my.disko.dualBoot = {
    enable = true;
    mode = "useExisting";
    disk = "/dev/sda";
    nixosPartition = "/dev/sda4";
  };

  # ── SSH Access
  my.services.ssh.authorizedKeys = [ flake.config.me.sshKey ];

  # ── UDisks2 (dynamic automount for USB/external drives) ─────────────────
  my.services.udisks2.enable = true;

  # ── DSC v3 YAML Generation (Nix→Windows managed config) ─────────────────
  # Auto-derives hostname, timezone, dark mode from NixOS config.
  # Adds aggressive Windows Update control + telemetry reduction.
  my.services.dscnix = {
    enable = false;
    configurationName = "DesktopWindowsDSC";

    # ── Gaming-only Windows: aggressive update management ────────────────
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
      "NoAutoRebootWithLoggedOnUsers" = {
        keyPath = "HKLM\\SOFTWARE\\Policies\\Microsoft\\Windows\\WindowsUpdate\\AU";
        valueName = "NoAutoRebootWithLoggedOnUsers";
        valueData = { DWord = 1; };
      };
      "AUOptions" = {
        keyPath = "HKLM\\SOFTWARE\\Policies\\Microsoft\\Windows\\WindowsUpdate\\AU";
        valueName = "AUOptions";
        valueData = { DWord = 3; };
      };
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
      "ExcludeWUDriversInQualityUpdate" = {
        keyPath = "HKLM\\SOFTWARE\\Policies\\Microsoft\\Windows\\WindowsUpdate";
        valueName = "ExcludeWUDriversInQualityUpdate";
        valueData = { DWord = 1; };
      };
      "DisableDeliveryOptimization" = {
        keyPath = "HKLM\\SOFTWARE\\Policies\\Microsoft\\Windows\\DeliveryOptimization";
        valueName = "DODownloadMode";
        valueData = { DWord = 0; };
      };
      "AllowTelemetry" = {
        keyPath = "HKLM\\SOFTWARE\\Policies\\Microsoft\\Windows\\DataCollection";
        valueName = "AllowTelemetry";
        valueData = { DWord = 1; };
      };
      "DisableTailoredExperiences" = {
        keyPath = "HKLM\\SOFTWARE\\Policies\\Microsoft\\Windows\\DataCollection";
        valueName = "AllowTailoredExperiencesWithDiagnosticData";
        valueData = { DWord = 0; };
      };
    };

    optionalFeatures = {
      "Microsoft-Windows-Subsystem-Linux" = { state = "Installed"; };
      "VirtualMachinePlatform" = { state = "Installed"; };
    };

    runCommands = {
      "RemoveBingBloat" = {
        executable = "powershell.exe";
        arguments = [ "-NoProfile" "-Command" "Get-AppxPackage *bing* | Remove-AppxPackage" ];
      };
    };
  };

  # ── VM Testing ─────────────────────────────────────────────────────────
  my.testing.vmTest.enable = true;

  # ── Ventoy: multi-boot USB (Windows ISO) ───────────────────────────────
  my.programs.ventoy.enable = true;

  my.ventoy.enable = true;
  my.ventoy.isos = {
    win11-23h2 = {
      source = flake.inputs.windows-iso-src.packages.x86_64-linux."windows-iso-22631.7079.23H2.PRO.X64.EN";
      target = "/iso/windows/22631.7079.23H2.PRO.X64.EN.iso";
    };
  };

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
