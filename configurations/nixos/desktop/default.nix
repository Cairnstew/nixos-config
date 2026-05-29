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
  # Expected disk: /dev/nvme0n1 (AMD desktop)
  #   p1: ESP (vfat, 100M) — Windows EFI boot
  #   p2: MSR (16M) — Microsoft Reserved
  #   p3: Windows (NTFS, ~150GB)
  #   p5: NixOS (ext4, rest) — created before first deploy
  #
  # First-time deploy (Windows exists with unallocated space):
  #   1. Create NixOS bootable USB:
  #        sudo dd if=<nixos-minimal-iso> of=/dev/sdX bs=4M status=progress
  #   2. Boot the USB on the desktop, select "NixOS installer" (not "live")
  #   3. Set the nixos user password (needed for SSH):
  #        passwd
  #   4. Find the desktop IP:
  #        ip a        # look for your LAN interface (e.g. enp4s0), note the IP
  #      Expected: 192.168.x.x or 100.x.x.x (Tailscale, if running)
  #   5. Check the partition table to confirm free space partition number:
  #        lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINT
  #      You should see:
  #        nvme0n1       (disk)
  #        ├─nvme0n1p1   (ESP, vfat, ~100M)
  #        ├─nvme0n1p2   (MSR, 16M)
  #        ├─nvme0n1p3   (Windows, NTFS, ~150G)
  #        └─nvme0n1p5   (free space — this is what we want)
  #      If the free space is at a different partition number (e.g. p4),
  #      update nixosPartition below before continuing.
  #   6. Format the NixOS partition:
  #        sudo mkfs.ext4 -L nixos /dev/nvme0n1p5   # adjust p5 if needed
  #   7. Add your SSH public key for passwordless auth:
  #        mkdir -p ~/.ssh
  #        curl -L https://github.com/Cairnstew.keys >> ~/.ssh/authorized_keys
  #      Or manually paste: echo "ssh-ed25519 AAAA..." >> ~/.ssh/authorized_keys
  #   8. From your source machine (laptop or wherever this repo is):
  #        nix run .#deploy -- desktop nixos@<desktop-IP>
  #      (uses nixos user because that's the user on the installer ISO;
  #       nixos-anywhere uses sudo to become root)
  #   9. After first boot, grab the host key and register with agenix:
  #        just register-host desktop <desktop-IP>
  my.disko.dualBoot = {
    enable = true;
    mode = "useExisting";
    disk = "/dev/nvme0n1";
    nixosPartition = "/dev/nvme0n1p5";
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

  # ── Ventoy: multi-boot USB ───────────────────────────────────────────
  my.programs.ventoy.enable = true;

  # Contribute Windows ISO to the Ventoy USB deployment
  my.ventoy.enable = true;
  my.ventoy.isos = {
    win11-23h2 = {
      source = flake.inputs.windows-iso-src.packages.x86_64-linux."windows-iso-22631.7079.23H2.PRO.X64.EN";
      target = "/iso/windows/22631.7079.23H2.PRO.X64.EN.iso";
    };
    nixos-installer = {
      source = flake.inputs.nixos-installer-iso;
      target = "/iso/linux/nixos-installer-x86_64-linux.iso";
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
