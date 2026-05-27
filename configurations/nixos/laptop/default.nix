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
        macAddress = "00:11:22:33:44:55"; # TODO: replace with actual MAC
        # discover → windows → nixos → done
        # discover: boots live env, user selects disk/hostname, POSTs to PXE server
        # windows:  automated unattended Windows install
        # nixos:    automated NixOS install with disko + nixos-install
        # done:     boot from local disk
        stages = [ "discover" "windows" "nixos" "done" ];
        # Note: diskoConfig and nixosConfig below are defaults for the automated
        # install stage. If discover runs first, it POSTs new values that override.

        windows.unattended = {
          enable = true;
          computerName = "DESKTOP";
          localUser = "nixos";
          password = "nixos123";  # temporary — change post-install
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
