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
    power.desktop.enable = true;
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

  # ── Docker Data Storage (sdb — 500GB SATA SSD) ────────────────────────
  # sdb → /mnt/docker, ext4, dedicated Docker data volume
  fileSystems."/mnt/docker" = {
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
  my.virtualisation.docker.dataRoot = "/mnt/docker";

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

  environment.systemPackages = with pkgs; [ gnome-monitor-config ntfs3g ];

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

    my.gnomeExtensions.custom.extensions = {
      host-info = {
        enable = true;
        name = "Host Info";
        description = "Shows hostname in the top bar";
        extensionJs = ''
          const { St, Clutter } = imports.gi;
          const Main = imports.ui.main;
          const PanelMenu = imports.ui.panelMenu;

          const hostname = "${config.networking.hostName}";

          let indicator = null;

          function init() {
            return { enable, disable };
          }

          function enable() {
            indicator = new PanelMenu.Button(0.0, "host-info", false);
            let box = new St.BoxLayout({ style_class: "panel-box" });
            let icon = new St.Icon({
              icon_name: "computer-symbolic",
              style_class: "system-status-icon"
            });
            box.add_child(icon);
            let label = new St.Label({
              text: hostname,
              y_align: Clutter.ActorAlign.CENTER
            });
            box.add_child(label);
            indicator.add_child(box);
            Main.panel.addToStatusArea("host-info", indicator, 0, "right");
          }

          function disable() {
            indicator?.destroy();
            indicator = null;
          }
        '';
      };
    };

    dconf.settings."org/gnome/shell" = {
      disable-user-extensions = false;
      enabled-extensions = [ "host-info@custom" ];
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
          + " -Lp -t normal -x 1200 -y 340 -M DP-1 -m '2560x1440@119.998'"
          + " -L  -t left   -x 3760 -y 7   -M DP-2 -m '1920x1200@59.950'"
          + " -L  -t right  -x 0    -y 0   -M DP-3 -m '1920x1200@59.950'";
      };
      Install = {
        WantedBy = [ "graphical-session.target" ];
      };
    };
  };
}
