# Laptop Configuration
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

  # ── Bootloader (was in configuration.nix, now inlined) ─────────────────
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelParams = [ "acpi_backlight=native" ];

  # ── System State ─────────────────────────────────────────────────────────
  system.stateVersion = "24.05";

  # ── System Identity ──────────────────────────────────────────────────────
  networking.hostName = "laptop";
  nixos-unified.sshTarget = "seanc@laptop";

  # ── System Profiles ──────────────────────────────────────────────────────
  my.profiles = {
    # Role
    workstation.enable = true;
    development.enable = true;

    # Desktop
    desktop.gnome.enable = true;

    # Hardware
    gpu.mesa.enable = true;
    battery.enable = true;
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
    latitude = 55.8617;
    longitude = 4.2583;
  };

  # ── Laptop-specific services ─────────────────────────────────────────────
  services.fwupd.enable = true;

  # ── Service Configuration ────────────────────────────────────────────────
  my.services.natShare = {
    enable = true;
    wanInterface = "wlp170s0";
    lanInterface = "enp0s13f0u2";
  };

  # ═══════════════════════════════════════════════════════════════════════════
  #  PXE Netboot Server — provisions the target desktop via ethernet
  # ═══════════════════════════════════════════════════════════════════════════
  #
  #  The desktop needs NOTHING pre-installed — no OS, no files, no config.
  #  Simply connect the ethernet cable between laptop and desktop, then set the
  #  desktop's BIOS to UEFI Network Boot (PXE). The laptop does everything.
  #
  #  ⚠  WARNING: The disko config below DESTROYS ALL DATA on /dev/nvme0n1.
  #     It creates a fresh GPT table: ESP → MSR → Windows (150G) → NixOS (rest).
  #     Back up anything important on the target machine before proceeding.
  #
  #  USAGE:
  #    sudo nixos-rebuild switch     # Install the config and tools
  #    sudo netboot-serve             # Start the interactive PXE server
  #      -i enp0s13f0u2               #   (interface matches natShare)
  #      -a 192.168.99.1              #   (same subnet as natShare)
  #
  #  The CLI prints status, accepts "advance <mac>" commands, and stops
  #  everything with Ctrl+C.  See --help for all options.
  #
  # ───────────────────────────────────────────────────────────────────────────
  my.services.netboot = {
    enable = true;
    interface = "enp0s13f0u2";
    serverAddress = "192.168.99.1";   # same subnet as natShare
    dhcpRange = "192.168.99.100,192.168.99.200";
    dhcpLeaseTime = "24h";

    windows.enable = true;
    nixos.enable = true;

    machines = {
      desktop = {
        macAddress = "a8:a1:59:8d:28:ec";
        # nixos → windows → done
        # nixos:  disko partitions disk (ESP→MSR→Windows→NixOS), then nixos-install
        #         to partition 4. Must run before Windows so disko's fresh GPT
        #         table doesn't wipe the Windows install.
        # windows: automated unattended Windows 11 install to pre-existing partition 3.
        # done:    boot from local disk.
        stages = [ "nixos" "windows" "done" ];

        windows.unattended = {
          enable = true;
          computerName = "DESKTOP";
          localUser = "nixos";
          password = "nixos123";  # temporary — change post-install
        };

        dscConfig = {
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

        nixos.autoInstall = {
          enable = true;

          diskoConfig = {
            disko.devices.disk.main = {
              type = "disk";
              device = "/dev/nvme0n1";
              content = {
                type = "gpt";
                partitions = {
                  esp = {
                    size = "1G";
                    type = "EF00";
                    content = {
                      type = "filesystem";
                      format = "vfat";
                      mountpoint = "/boot";
                    };
                  };
                  msr = {
                    size = "16M";
                    type = "MSR";
                    content = null;
                  };
                  windows = {
                    size = "150G";
                    content = {
                      type = "filesystem";
                      format = "ntfs";
                      mountpoint = null;
                    };
                  };
                  nixos = {
                    size = "100%";
                    content = {
                      type = "filesystem";
                      format = "ext4";
                      mountpoint = "/";
                    };
                  };
                };
              };
            };
          };

          nixosConfig = ''
            { config, pkgs, lib, ... }: {
              system.stateVersion = "25.05";
              networking.hostName = "desktop";
              nixpkgs.hostPlatform = "x86_64-linux";

              boot.loader = {
                efi.canTouchEfiVariables = true;
                grub = {
                  enable = true;
                  devices = [ "nodev" ];
                  efiSupport = true;
                  extraEntries = '''
                    menuentry "Windows 11" {
                      search --set=root --label ESP
                      chainloader /EFI/Microsoft/Boot/bootmgfw.efi
                    }
                  ''';
                };
              };

              services.xserver.enable = true;
              services.xserver.desktopManager.gnome.enable = true;
            }
          '';
          # TODO: generate hardware-configuration.nix on the target
          # and add: imports = [ ./hardware-configuration.nix ];
        };
      };
    };

    # ── Reusable Boot Profiles (used by netboot-serve wizard) ──────────────
    profiles = {
      dual-boot = {
        enable = true;
        description = "NixOS + Windows 11 dual boot (fully automated)";
        stages = [ "nixos" "windows" "done" ];
        windows.unattended = {
          enable = true;
          computerName = "DESKTOP";
          localUser = "nixos";
          password = "nixos123";
        };
        dscConfig = {
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
        nixos.autoInstall = {
          enable = true;
          diskoConfig = {
            disko.devices.disk.main = {
              type = "disk";
              device = "/dev/nvme0n1";
              content = {
                type = "gpt";
                partitions = {
                  esp = { size = "1G"; type = "EF00"; content.type = "filesystem"; format = "vfat"; mountpoint = "/boot"; };
                  msr = { size = "16M"; type = "MSR"; content = null; };
                  windows = { size = "150G"; content.type = "filesystem"; format = "ntfs"; mountpoint = null; };
                  nixos = { size = "100%"; content.type = "filesystem"; format = "ext4"; mountpoint = "/"; };
                };
              };
            };
          };
          nixosConfig = ''
            { config, pkgs, lib, ... }: {
              system.stateVersion = "25.05";
              networking.hostName = "desktop";
              nixpkgs.hostPlatform = "x86_64-linux";
              boot.loader = {
                efi.canTouchEfiVariables = true;
                grub = {
                  enable = true;
                  devices = [ "nodev" ];
                  efiSupport = true;
                  extraEntries = '''
                    menuentry "Windows 11" {
                      search --set=root --label ESP
                      chainloader /EFI/Microsoft/Boot/bootmgfw.efi
                    }
                  ''';
                };
              };
              services.xserver.enable = true;
              services.xserver.desktopManager.gnome.enable = true;
            }
          '';
        };
      };

      nixos-minimal = {
        enable = true;
        description = "NixOS only (erase entire disk)";
        stages = [ "nixos" "done" ];
        nixos.autoInstall = {
          enable = true;
          diskoConfig = {
            disko.devices.disk.main = {
              type = "disk";
              device = "/dev/nvme0n1";
              content = {
                type = "gpt";
                partitions = {
                  esp = { size = "1G"; type = "EF00"; content.type = "filesystem"; format = "vfat"; mountpoint = "/boot"; };
                  nixos = { size = "100%"; content.type = "filesystem"; format = "ext4"; mountpoint = "/"; };
                };
              };
            };
          };
          nixosConfig = ''
            { config, pkgs, lib, ... }: {
              system.stateVersion = "25.05";
              networking.hostName = "nixos";
              nixpkgs.hostPlatform = "x86_64-linux";
              boot.loader.grub = { enable = true; devices = [ "nodev" ]; efiSupport = true; };
              services.xserver.enable = true;
              services.xserver.desktopManager.gnome.enable = true;
            }
          '';
        };
      };

      windows-only = {
        enable = true;
        description = "Pure Windows 11 (entire disk)";
        stages = [ "windows" "done" ];
        windows.unattended = {
          enable = true;
          computerName = "WINDOWS-PC";
          localUser = "nixos";
          password = "nixos123";
        };
      };
    };
  };

  # ── Windows ISO sync (for PXE boot files) ────────────────────────────────
  my.services.windowsIsoSync.enable = true;

  # ── Additional Programs ────────────────────────────────────────────────
  my.programs.ventoy.enable = true;
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
