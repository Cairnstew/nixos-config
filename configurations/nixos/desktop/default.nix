{ config, lib, pkgs, flake, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./configuration.nix
    ./disk-config.nix
    flake.inputs.self.nixosModules.common
  ];

  nixpkgs.hostPlatform = "x86_64-linux";
  system.stateVersion = "26.05";
  networking.hostName = "desktop";
  nixos-unified.sshTarget = "seanc@desktop";

  # ── VM Builder ──────────────────────────────────────────────────────────────
  # Build VM packages for testing before deploying to real hardware.
  # The extraConfig strips GPU/gaming/battery config that doesn't work in QEMU
  # and switches to a lightweight Hyprland desktop.
  my.vm = {
    enable = true;
    # hosts = [];  # empty = all hosts, or list specific ones
    extraConfig = { lib, pkgs, ... }: {
      my.profiles = {
        workstation.enable = lib.mkForce false;
        gaming.enable = lib.mkForce false;
        gpu.mesa.enable = lib.mkForce false;
        location.enable = lib.mkForce false;
        desktop.choice = lib.mkForce "hyprland";
      };
      my.system.battery.enable = lib.mkForce false;
      my.testing.startAtBoot = true;

      services.greetd = {
        enable = true;
        settings = {
          default_session = {
            command = lib.mkForce "${pkgs.hyprland}/bin/Hyprland";
            user = lib.mkForce "seanc";
          };
        };
      };
    };
  };

  # Always run at performance governor (desktop, always plugged in)
  powerManagement.cpuFreqGovernor = "performance";

  # ── System Profiles ──────────────────────────────────────────────────────
  my.profiles = {
    workstation.enable = true;
    development.enable = true;
    entertainment.enable = true;
    gpu.mesa.enable = true;
    location.enable = true;
    gaming.enable = true;
    testing.enable = true;
    theming.stylix.enable = true;
  };

  # ── Desktop Environment ────────────────────────────────────────────────────
  # Toggle between "hyprland" and "gnome" to switch desktop environments.
  # my.profiles.desktop.choice = "hyprland";
  my.profiles.desktop.choice = "gnome";

  # ── Monitor Layout ─────────────────────────────────────────────────────────
  # DP-1: 2560×1440 @ 144Hz (primary, left)
  # HDMI-A-1: 1920×1080 @ 60Hz (right of DP-1, portrait orientation)
  my.monitors = [
    {
      name = "DP-1";
      width = 2560;
      height = 1440;
      refreshRate = 144;
      x = 0;
      y = 0;
      primary = true;
      workspace = "1";
    }
    {
      name = "HDMI-A-1";
      width = 1920;
      height = 1080;
      refreshRate = 60;
      x = 2560;
      y = 0;
      transform = 1;
      workspace = "2";
    }
  ];

  my.programs.proton.ge.enable = true;

  my.programs.steam = {
    shaderPreCaching.enable = true;
    gamemode.enable = true;
    games.overwatch-2 = {
      appId = "2357570";
      name = "Overwatch 2";
    };
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

  # ── Partition Layout (existing, DO NOT REPARTITION)
  #   label "EFI":    vfat  512M  ESP — shared Windows/NixOS EFI
  #   MSR:            —      16M   Microsoft Reserved
  #   label "Windows": ntfs  ~80G  Windows C: drive
  #   label "nixos":  ext4  rest  NixOS root
  #
  # Uses /dev/disk/by-label/ paths (stable across reboots).
  #
  # Filesystem mounts managed by disko.devices.nodev in disk-config.nix.
  # Deploy with --disko-mode format (first deploy) or --disko-mode mount (redeploys).

  # ── Filesystems (explicit, must match disk-config.nix nodev devices)
  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/EFI";
    fsType = "vfat";
    options = [ "umask=0077" ];
  };

  # ── Bootloader (GRUB EFI, dual-boot with Windows)
  boot.loader.grub.enable = true;
  boot.loader.grub.devices = [ "nodev" ];
  boot.loader.grub.efiSupport = true;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.loader.grub.extraEntries = ''
    menuentry "Windows 11" {
      insmod part_gpt
      insmod fat
      insmod chain
      search --no-floppy --label --set=root ESP
      chainloader /EFI/Microsoft/Boot/bootmgfw.efi
    }
  '';

  # ── Windows post-install: restore GRUB EFI boot order
  # Windows Setup always sets itself as the first EFI boot entry.
  # This oneshot service runs once after first boot to repair the order
  # so GRUB comes before Windows Boot Manager.
  systemd.services.windows-post-install = {
    description = "Restore GRUB EFI boot order after Windows install";
    after = [ "boot-complete.target" ];
    wants = [ "boot-complete.target" ];

    path = [ pkgs.efibootmgr ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      StateDirectory = "windows-post-install";
    };

    script = ''
      set -euo pipefail

      STAMP="/var/lib/windows-post-install/.done"
      if [ -f "$STAMP" ]; then
        exit 0
      fi
      mkdir -p "$(dirname "$STAMP")"

      echo "[windows-post-install] Checking EFI boot order..."
      BOOTMGR="$(efibootmgr -v 2>/dev/null || true)"
      echo "$BOOTMGR"

      CURRENT_ORDER=$(echo "$BOOTMGR" | grep "^BootOrder:" | sed 's/^BootOrder: //')

      NIXOS_ID=$(echo "$BOOTMGR" | grep -i "NixOS\|GRUB" | grep "^Boot[0-9a-fA-F]\{4\}" | sed 's/^Boot\([0-9a-fA-F]\{4\}\).*/\1/' | head -1)
      WIN_ID=$(echo "$BOOTMGR" | grep -i "Windows Boot Manager" | grep "^Boot[0-9a-fA-F]\{4\}" | sed 's/^Boot\([0-9a-fA-F]\{4\}\).*/\1/' | head -1)

      # Remove stale "Windows 11 Setup" entries from installer ISO
      STALE=$(echo "$BOOTMGR" | grep -i "Windows 11 Setup" | grep "^Boot[0-9a-fA-F]\{4\}" | sed 's/^Boot\([0-9a-fA-F]\{4\}\).*/\1/')
      for entry in $STALE; do
        echo "[windows-post-install] Removing stale entry Boot$entry..."
        efibootmgr -b "$entry" -B 2>/dev/null || true
      done

      if [ -n "$NIXOS_ID" ] && [ -n "$WIN_ID" ]; then
        NEW_ORDER="$NIXOS_ID"
        for entry in $(echo "$CURRENT_ORDER" | tr ',' ' '); do
          if [ "$entry" != "$NIXOS_ID" ]; then
            NEW_ORDER="$NEW_ORDER,$entry"
          fi
        done
        echo "[windows-post-install] Setting boot order: $NEW_ORDER"
        efibootmgr -o "$NEW_ORDER" 2>/dev/null || true
        echo "[windows-post-install] Boot order repaired."
      else
        echo "[windows-post-install] Could not find NixOS entry ($NIXOS_ID) or Windows entry ($WIN_ID) — skipping"
      fi

      touch "$STAMP"
      echo "[windows-post-install] Complete."
    '';
  };

  # ── SSH Access
  my.services.ssh.authorizedKeys = [ flake.config.me.sshKey ];

  # ── Data Volume (sdb — 500GB SATA SSD) ────────────────────────────────
  # sdb → /mnt/data, ext4, Docker + Ollama data
  fileSystems."/mnt/data" = {
    device = "/dev/disk/by-label/docker-data";
    fsType = "ext4";
  };

  # nvme0n1 (CT2000T500SSD5 2TB) → /mnt/media
  fileSystems."/mnt/media" = {
    device = "/dev/disk/by-uuid/9AFA1F50FA1F2851";
    fsType = "ntfs-3g";
    options = [ "rw" "uid=1000" "gid=100" "umask=0022" "nofail" "x-systemd.automount" ];
  };

  # ── Docker ──────────────────────────────────────────────────────────────
  # Move Docker data to the dedicated 500GB SATA SSD (sdb) for space
  my.virtualisation.docker.dataRoot = "/mnt/data/docker";

  # ── DP Link Retrain: force HBR2 on DP-1 after boot ──────────────────────
  # The amdgpu link training sometimes falls back to HBR (2.7 Gbps/lane)
  # during concurrent multi-monitor init. This triggers a hotplug retrain
  # at the end of boot to establish HBR2 (5.4 Gbps/lane) for 1440p@120Hz.
  systemd.services.dp-link-retrain = {
    description = "Retrain DP-1 link at HBR2 for high-bandwidth modes";
    after = [ "graphical.target" ];
    wants = [ "graphical.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      set -euo pipefail
      sleep 5
      HPDIR="/sys/kernel/debug/dri/0000:07:00.0/DP-1"
      if [ -w "$HPDIR/trigger_hotplug" ]; then
        echo 1 > "$HPDIR/trigger_hotplug" 2>/dev/null || true
      fi
    '';
  };

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

  # ── Ventoy: multi-boot USB (Windows ISO) ───────────────────────────────
  my.programs.ventoy.enable = true;

  my.ventoy.enable = true;
  my.ventoy.isos = {
    win11-23h2 = {
      source = flake.inputs.windows-iso-src.packages.x86_64-linux."windows-iso-22631.7079.23H2.PRO.X64.EN";
      target = "/iso/windows/22631.7079.23H2.PRO.X64.EN.iso";
    };
  };

  # ── LLM / AI ─────────────────────────────────────────────────────────────
  my.services.sillytavern = {
    enable = true;
    ollama.enable = true;
  };

  # ── Manga Reader ─────────────────────────────────────────────────────────
  # Suwayomi-Server backend + Moku frontend (both enabled via entertainment profile)
  my.services.suwayomi = {
    settings.server = {
      ip = "0.0.0.0";
      extensionRepos = [
        "https://raw.githubusercontent.com/keiyoushi/extensions/repo/index.min.json"
      ];
    };
    openFirewall = true;
    extraReadWritePaths = [ "/mnt/media/suwayomi" ];
  };

  # Only the desktop manages tailscale ACL policy (auth keys, port grants)
  my.services.tailscale.manager = {
    enable = true;
    policy.interNodePorts = [ "tcp:22" "tcp:4567" ];
  };

  my.services.ollama = {
    enable = false;
    gpu.enable = true;
    gpu.type = "amd";
    dataDir = "/mnt/data/ollama";
    models = flake.config.ollamaModels;
  };

  environment.systemPackages = with pkgs; [ ntfs3g ];

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

    # GNOME-specific extras removed: host-info extension (broken/unused),
    # dconf shell settings, and gnome-monitor-config service (replaced by my.monitors)
  };
}
