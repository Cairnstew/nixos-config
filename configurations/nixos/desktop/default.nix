{ config, lib, pkgs, flake, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./configuration.nix
    ./disk-config.nix
    flake.inputs.self.nixosModules.common
  ];

  system.stateVersion = "26.05";
  networking.hostName = "desktop";
  nixos-unified.sshTarget = "seanc@desktop";

  # ── VM Builder ──────────────────────────────────────────────────────────────
  # Build VM packages for testing before deploying to real hardware.
  # The extraConfig strips GPU/gaming/battery config that doesn't work in QEMU
  # and switches to a lightweight Hyprland desktop.
  my.vm = {
    enable = true;
    memory = 4096;
    cores = 4;
    extraConfig = { lib, pkgs, ... }: {
      my.profiles = {
        workstation.enable = lib.mkForce false;
        gaming.enable = lib.mkForce false;
        gpu.mesa.enable = lib.mkForce false;
        location.enable = lib.mkForce false;
        desktop.choice = lib.mkForce "hyprland";
      };
      my.system.battery.enable = lib.mkForce false;
      # VM-only: Caddy loopback in QEMU test VM (DECISION LOG R3).
      my.services.proxy.listenAddresses = lib.mkForce [ "127.0.0.1" ];
      my.testing = {
        # T3: stale F16 comment removed (recon H8) — it referenced an "enable=true
        #     redundant" finding, but the value below is startAtBoot = true, not
        #     enable, so the comment was wrong. Keep startAtBoot.
        startAtBoot = true;
      };

      services.greetd = {
        enable = true;
        settings = {
          default_session = {
            command = lib.mkForce "${pkgs.hyprland}/bin/start-hyprland";
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
    entertainment.enable = true;
    gpu.mesa.enable = true;
    location.enable = true;
    gaming.enable = true;
    media.enable = true;
    testing.enable = true;
    theming.stylix.enable = true;
  };

  # ── Mouse ─────────────────────────────────────────────────────────────────
  # Kernel-level acceleration via maccel (enabled by gaming profile).
  # sensMultiplier 2.0 = 2× base sensitivity before acceleration.
  # outputCap 3.0 = max 3× boost at high speeds.
  my.hardware.mouse.parameters = {
    sensMultiplier = 2.0;
    acceleration = 0.3;
    offset = 4.0;
    outputCap = 3.0;
  };

  # ── Vulkan ────────────────────────────────────────────────────────────────
  # Required for native Vulkan games (Satisfactory, etc.). Adds vulkan-loader,
  # validation layers, and 32-bit support for mod DLLs.
  my.hardware.vulkan.enable = true;

  # ── Audio: virtual mixer + declared default mic ──────────────────────────
  # Pulsemeeter provides VoiceMeeter-style virtual buses; EasyEffects adds
  # per-stream EQ/compression. The mic name is baked into WirePlumber config as
  # the default source — update `name` from `wpctl status` if it differs.
  my.system.audio = {
    # Boost the integrated Realtek ALCS1200A analog output (front / rear 3.5mm
    # jacks — passive headphones rely entirely on the motherboard DAC/amp and
    # come up too quiet at WirePlumber's global 40%). Bluetooth headsets are
    # self-amplified, so they're left on the global default.
    deviceDefaultVolumes = {
      "alsa_card.pci-0000_09_00.4" = 0.8;
    };
    virtualMixer = {
      enable = true;
      patchbay = "qpwgraph";
    };
    mic = {
      enable = true;
      name = "alsa_input.usb-C-Media_Electronics_Inc._USB_PnP_Sound_Device-00.analog-stereo";
      description = "USB headset";
    };
  };

  # ── Desktop Environment ────────────────────────────────────────────────────
  # Toggle between "hyprland" and "gnome" to switch desktop environments.
  my.profiles.desktop.choice = "hyprland";
  # my.profiles.desktop.choice = "gnome";

  # ── Monitor Layout ─────────────────────────────────────────────────────────
  # DP-1: 2560×1440 @ 120Hz (center, primary)
  # DP-3: 1920×1200 @ 60Hz (right, portrait) — Dell U2412M
  # DP-2: 1920×1200 @ 60Hz (left, portrait) — Dell U2412M
  my.monitors = [
    {
      name = "DP-3";
      width = 1920;
      height = 1200;
      refreshRate = 60;
      x = 3760;
      y = 0;
      transform = 1;
      workspace = "3";
    }
    {
      name = "DP-1";
      width = 2560;
      height = 1440;
      refreshRate = 120;
      x = 1200;
      y = 240;
      primary = true;
      workspace = "1";
    }
    {
      name = "DP-2";
      width = 1920;
      height = 1200;
      refreshRate = 60;
      x = 0;
      y = 0;
      transform = 3;
      workspace = "2";
    }
  ];

  my.desktop.hyprland = {
    core = {
      workspaceStartup = [
        {
          workspace = "1";
          command = "ghostty";
          class = "com.mitchellh.ghostty";
        }
        {
          workspace = "2";
          command = "spotify";
          class = "Spotify";
          silent = true;
        }
        {
          workspace = "2";
          command = "firefox";
          class = "firefox";
          silent = true;
        }
        {
          workspace = "3";
          command = "ghostty";
          class = "com.mitchellh.ghostty";
          silent = true;
        }
        {
          workspace = "3";
          command = "thunar";
          class = "thunar";
          silent = true;
        }
      ];

      extraExecOnce = [ "playerctld daemon" ];

      # Launch the Project Zomboid client host with the ZombieBuddy JVM agent.
      # Steam's launch-options field is per-machine and un-versioned, so the
      # agent lives in the repo instead — see
      # modules/nixos/projectzomboid-server/config.nix, which also ships a
      # desktop entry so this is reachable from wofi and not only the keybind.
      extraBinds = [
        "$mod, G, exec, projectzomboid-viewpoint"
      ];

      debug.enable = true;
      accelProfile = "flat";
    };

    appearance = {
      enable = true;
      windowOpacity = {
        enable = true;
        focused = 0.93;
        unfocused = 0.80;
      };
    };

    wallpapers = {
      images =
        let
          shinyColors = pkgs.fetchurl {
            url = "https://raw.githubusercontent.com/AlexandrosLiaskos/Awesome_Wallpapers/main/images/shiny-colors.png";
            sha256 = "07ihb3352vfp5kw5f0rls9bzwxr6mrgflqh52mygh8bjck2hj3y3";
          };
          shinyColorsFlipped = pkgs.runCommandLocal "shiny-colors-flipped.png"
            {
              nativeBuildInputs = [ pkgs.imagemagick ];
            } ''
            convert ${shinyColors} -flop "$out"
          '';
        in
        [
          {
            output = "DP-3";
            path = shinyColors;
          }
          {
            output = "DP-1";
            path = pkgs.fetchurl {
              url = "https://raw.githubusercontent.com/AlexandrosLiaskos/Awesome_Wallpapers/main/images/lake.jpg";
              sha256 = "0ab3hjvg752phd963bc5r76fmpkfxdx7p75bmgcqm0kikh0wy64h";
            };
          }
          {
            output = "DP-2";
            path = shinyColorsFlipped;
          }
        ];
    };

    displayManager.greeter = "sddm";

    bar.customModules.spotify-now-playing = {
      # Absolute path: waybar runs under its own systemd user unit whose PATH
      # does NOT include /etc/profiles/per-user/<user>/bin (bare "spotify-now-playing"
      # fails with "command not found" on every tick — see waybar unit logs).
      exec = "/etc/profiles/per-user/${flake.config.me.username}/bin/spotify-now-playing";
      interval = 5;
      returnType = "json";
      tooltip = true;
      position = "left";
      order = 0;
      # Left-click opens Spotify (or runs sign-in when not authenticated).
      on-click = "/etc/profiles/per-user/${flake.config.me.username}/bin/spotify-widget-click";
    };

    # Inline horizontal media-control buttons, immediately right of the song
    # info (order pins the left-to-right sequence: ◀ ⏯ ▶). Static-glyph custom
    # modules — no exec, no polling — each with its own on-click. (waybar's
    # GtkMenu popup is vertical-only, so a horizontal row means separate
    # modules.) Absolute paths: waybar's unit PATH has no profile bin.
    bar.customModules.spotify-back = {
      format = "⏮";
      tooltip = false;
      position = "left";
      order = 1;
      on-click = "/etc/profiles/per-user/${flake.config.me.username}/bin/spotify-widget-click previous";
    };
    bar.customModules.spotify-play = {
      format = "⏯";
      tooltip = false;
      position = "left";
      order = 2;
      on-click = "/etc/profiles/per-user/${flake.config.me.username}/bin/spotify-widget-click toggle";
    };
    bar.customModules.spotify-forward = {
      format = "⏭";
      tooltip = false;
      position = "left";
      order = 3;
      on-click = "/etc/profiles/per-user/${flake.config.me.username}/bin/spotify-widget-click next";
    };

    # Upvote button: exec mode shows vote count via upstream CLI, click upvotes
    # the current song. Requires my.programs.spotify.player.upvote.enable = true
    # (enabled by default in the desktop home profile). The wrapper exports
    # SPOTIFY_* creds then delegates to the upstream spotify-playlist-manager
    # `waybar upvote --json` / `waybar upvote` subcommands.
    bar.customModules.spotify-upvote = {
      exec = "/etc/profiles/per-user/${flake.config.me.username}/bin/spotify-upvote --json";
      interval = 30;
      returnType = "json";
      tooltip = true;
      position = "left";
      order = 4;
      on-click = "/etc/profiles/per-user/${flake.config.me.username}/bin/spotify-upvote";
    };

    # OpenCode Go usage: rolling/weekly/monthly budget consumption from the
    # cached usage snapshot (refreshed every 5m by the systemd timer).
    bar.customModules.opencode-usage = {
      exec = "/etc/profiles/per-user/${flake.config.me.username}/bin/opencode-go-waybar";
      interval = 60;
      returnType = "json";
      tooltip = true;
      position = "right";
      order = 90; # right of custom/opencode-key, left of nothing (last)
    };

    # OpenCode general-provider token indicator + toggle. Shows OC1/OC2 for the
    # live `opencode` credential in auth.json; clicking flips it between the
    # opencode-token / opencode-token-2 agenix secrets without a rebuild.
    # --click notifies + sends waybar SIGUSR2 so the label repaints at once
    # rather than waiting out the interval. Absolute paths: waybar's unit PATH
    # does NOT include /etc/profiles/per-user/<user>/bin (see the comment on
    # spotify-now-playing above).
    bar.customModules.opencode-key = {
      exec = "/etc/profiles/per-user/${flake.config.me.username}/bin/opencode-key-toggle --json";
      interval = 30;
      returnType = "json";
      tooltip = true;
      position = "right";
      order = 89; # just left of opencode-usage, both in the right cluster
      on-click = "/etc/profiles/per-user/${flake.config.me.username}/bin/opencode-key-toggle --click";
    };
  };

  my.programs.proton.ge.enable = true;

  # ── Jupyter ──────────────────────────────────────────────────────────────
  # The jupyter service user needs to traverse /home/seanc to reach
  # ~/Documents/jupyter_projects/. Mode 710 lets the users group
  # (which includes jupyter) execute through the home directory.
  my.services.jupyter = {
    passwordFile = config.age.secrets.jupyter-password.path;
  };
  system.activationScripts.jupyter-home-permissions = ''
    chmod 710 /home/${flake.config.me.username}
  '';

  # ── Houdini (SideFX 3D/VFX) ─────────────────────────────────────────────
  # Requires the SideFX installer tarball in the store (already present /
  # build cached). If it's ever GC'd, re-add it with:
  #   nix-store --add-fixed sha256 houdini-22.0.368-linux_x86_64_gcc14.2.tar.gz
  my.programs.houdini.enable = true;
  # Package from the houdini-nix flake (newer builds than nixpkgs' 21.0.559).
  my.programs.houdini.package =
    flake.inputs.houdini-nix.packages.x86_64-linux.houdini-22_0_368;
  # SideFX Labs free toolset (shelves + HDAs) — installed declaratively like
  # the Launcher's install-package, pinned to 22.0.459.
  my.programs.houdini.labs.enable = true;
  # Auto-renew Apprentice (NC) license via SideFX License API.
  my.programs.houdini.redeemNonCommercial = {
    enable = true;
    serverCode = "2c4769a8";
  };

  my.programs.steam = {
    shaderPreCaching.enable = true;
    gamemode.enable = true;
    games = {
      overwatch-2 = {
        appId = "2357570";
        name = "Overwatch 2";
        gamescope = {
          enable = true;
          width = 2560;
          height = 1440;
          refreshRate = 120;
          extraArgs = [
            "--prefer-output"
            "DP-1" # fullscreen on the main gaming monitor
            "--immediate-flips" # reduce latency / stutter
          ];
        };
      };
      satisfactory = {
        appId = "526870";
        name = "Satisfactory";
        env = {
          # Disable Steam's Fossilize layer — it deadlocks with RADV during
          # Satisfactory's heavy UE5 Vulkan pipeline compilation, causing
          # "Compiling Vulkan Shaders" to hang forever.
          STEAM_SHADER_CACHE_DISABLE = "1";
          VK_LAYER_DISABLE = "Fossilize";
        };
      };
    };
  };

  my.homeProfiles = {
    common.enable = true;
    desktop.enable = true;
    development.enable = true;
  };

  # ── nix-ld (run unpatched ELF binaries) ──────────────────────────────────
  # Root fix for Zed's downloaded language servers. With no system `node` on
  # PATH, Zed downloads its own generic-Linux Node (and ruff as a native
  # binary); NixOS' stub-ld loader cannot exec either, so
  # bash-language-server / json-language-server / ruff all fail to start.
  # nix-ld replaces the stub loader and covers every current and future
  # download, in every project. See modules/nixos/nix-ld/README.md.
  my.system.nix-ld.enable = true;

  # ── Reverse Proxy ────────────────────────────────────────────────────────
  # Unified proxy module: services auto-register with my.services.proxy.upstreams.
  # Caddy serves the service dashboard at / and proxies subpaths to each backend.
  # tailscale serve forwards :443 → Caddy:8081 so each service is at
  # https://desktop.tail685690.ts.net/<service>/.
  my.services.proxy = {
    listenAddresses = [ "100.121.125.58" "127.0.0.1" ];
    tailscaleServe.enable = true;
  };

  # ── Location ────────────────────────────────────────────────────────────
  # T3: my.system.location block removed (recon H3) — timeZone "Europe/London"
  #     equals the current-location.nix:19 default (flake config.nix:135), so the
  #     block was behavior-identical to the default. Profile enable still applies
  #     via my.profiles.location.enable = true.

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

  # ── Email alerts ─────────────────────────────────────────────────────────
  my.services.emailAlerts.enable = true;

  # ── Backup Source ───────────────────────────────────────────────────────
  # Push /home/seanc to the server's restic repository over SFTP (tailnet
  # SSH port 22). Inert until the backup-repo-passphrase agenix secret exists.
  my.services.backup-source = {
    enable = true;
    jobs.home = {
      paths = [ "/home/seanc" ];
    };
  };

  # ── SSH Access
  # F12: authorizedKeys inherited from common.nix mkDefault (single source of truth)

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

  # ── Project Zomboid: Project Viewpoint Vanilla+ ───────────────────────────
  # /mnt/data is 0771 root:users: the `users` group (which includes the primary
  # user) gets full rwx so the user can list/read/create directly, while "other"
  # keeps traverse-only (--x, no listing). "Other" traverse is required because
  # the `project-zomboid` service user is not in `users` and must still TRAVERSE
  # every ancestor to reach its own data dir. Deny it and the install unit dies
  # at exec with `status=200/CHDIR`, before its script ever runs — the module
  # creates /mnt/data/project-zomboid itself (upstream modules/config.nix sets a
  # tmpfiles rule "d '${dataDir}' 0770 <user> <group>", which runs as root and
  # therefore succeeds), but traverse on every ancestor is required for any
  # access.
  #
  # This exposes nothing new: the sensitive subdirs already deny others `x`
  # (docker 0710 root:root, project-zomboid 0770 project-zomboid, lost+found
  # 0700 root:root), while the ones that are world-readable (ollama 0755,
  # jupyter_projects 0775) already say so in their own modes.
  systemd.tmpfiles.rules = [
    "d /mnt/data 0771 root users -"
    # OBS recordings (my.programs.obs-studio.recordingPath below). /mnt/data is
    # root-owned so tmpfiles can descend; the recording user needs write access.
    "d /mnt/data/obs-recordings 0755 ${flake.config.me.username} users -"
  ];

  # The server ships disabled (modules/nixos/projectzomboid-server/servers/
  # viewpoint.nix) — opt in per host here.
  #
  # Build drift: Project Viewpoint pins `versionMin=42.21 versionMax=42.21`, and
  # the stable branch currently ships exactly 42.21.0. When PZ moves past 42.21
  # the game HIDES Viewpoint rather than failing, so the server keeps running
  # but loses the renderer. To freeze the install, set `updateOnStart = false`
  # once it exists (that option never creates one) and bump deliberately after
  # re-checking Viewpoint's mod.info.
  # NO dedicated server on this host. The world is hosted from the game's own
  # in-game Host button instead — see servers/viewpoint.nix → clientHost.
  #
  # TEMPORARILY DISABLED (2026-10-08): with `enable = true` this runs
  # project-zomboid-install.service (a steamcmd validate), which now fails the
  # whole `nixos-rebuild switch` (exit 4): no `cairnsgerry` login token is cached
  # under HOME=/mnt/data/project-zomboid ("Cached credentials not found"), and a
  # systemd unit has no TTY to answer the password prompt it falls back to. To
  # restore: run the one-time login (see `steamLogin` below) or drop it, then
  # set `enable = true`. When enabled it renders the client config and keeps the
  # shared Workshop download current; the server itself stays off via
  # `servers.viewpoint.enable = false`.
  services.project-zomboid-servers = {
    enable = false;
    servers.viewpoint.enable = false;

    # Authenticate the shared steamcmd install as cairnsgerry instead of
    # `anonymous`, so Workshop items anonymous cannot fetch (mature-content
    # gated, or author-restricted) land. This names the account ONLY — the
    # password is never stored. SteamCMD caches a login token under the data
    # dir's HOME, so log in ONCE as the service user:
    #   sudo -u project-zomboid env HOME=/mnt/data/project-zomboid \
    #     <steamcmd> +login cairnsgerry
    steamLogin = "cairnsgerry";

    # ttyd consoles front a SERVER's console; with no server enabled there is
    # nothing to front. Off, which also drops the `project-zomboid-web` user and
    # its polkit rule.
    web.enable = false;
  };

  # The client's Zomboid home is seeded by the upstream module's Home Manager
  # half, imported for every host in modules/nixos/projectzomboid-server/. All
  # that is left here is the world itself.

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
  # T3: my.services.dscnix block removed (recon H7) — service was disabled
  #     (enable = false) with a full unused registry/optionalFeatures/runCommands
  #     payload (~60 lines). The disabled service had no effect, so removal is
  #     behavior-identical. Re-enable the service before repopulating this config.
  #     (Previously auto-derived hostname/timezone/dark mode and added aggressive
  #     Windows Update control + telemetry reduction for the gaming-only Windows.)

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
  # Options live under `services.sillytavern-nixos.*` — the upstream
  # github:Cairnstew/SillyTavern flake module, wrapped by
  # modules/nixos/sillytavern. The namespace is NOT `services.sillytavern`:
  # that one belongs to nixpkgs' own module, and the two cannot be enabled at
  # the same time (they share the unit, the account and the state directory).
  services.sillytavern-nixos = {
    # Disabled on desktop: the entertainment profile turns it on via
    # lib.mkDefault, and the declarative config below is kept for re-enabling.
    enable = lib.mkForce false;

    # ── Server ──────────────────────────────────────────────────────────
    config.port = 8000;
    config.whitelistMode = false;
    # Extensions are declarative from the Nix store, so the UI's "update
    # extensions" button would fail against a read-only path. Upstream forces
    # this off as well; it is spelled out here for the record.
    config.extensions.autoUpdate = false;

    # ── Presets ──────────────────────────────────────────────────────────
    # One JSON file per named item, seeded into every account's data root.
    presets.common = {
      # Text Completion presets — Settings → AI Response Configuration.
      # Settings from the model card:
      # https://huggingface.co/ArliAI/DS-R1-Qwen3-8B-ArliAI-RpR-v4-Small
      # RpR models don't work well with repetition penalty samplers
      # (XTC, DRY, rep_pen).
      textGeneration.Reasoning = {
        json = {
          temp = 1.0;
          top_k = 40;
          top_p = 1.0;
          min_p = 0.02;
          do_sample = true;
          include_reasoning = true;
          genamt = 2048;
          rep_pen = 1.0;
        };
      };

      # Advanced Formatting templates — named after the ArliAI RpR v4 model.
      # Note: separator must match what the model actually outputs between
      # </think> and response. The model outputs a single newline, so
      # separator is "\n" (not "\n\n").
      reasoning."DS-R1-Qwen3-8B-ArliAI-RpR-v4-Small" = {
        json = {
          prefix = "<think>";
          suffix = "</think>";
          separator = "\n";
        };
      };
      sysprompt."DS-R1-Qwen3-8B-ArliAI-RpR-v4-Small" = {
        json = {
          content = ''
            You are a roleplaying AI with deep reasoning capabilities, based on the ArliAI RpR v4 model. Use <think> </think> tags for internal reasoning before responding. Stay in character and write creatively, responding from {{char}}'s perspective. Follow the character description and scenario closely.'';
        };
      };
      context."DS-R1-Qwen3-8B-ArliAI-RpR-v4-Small" = {
        json = {
          story_string = "{{#if system}}{{system}}\n{{/if}}{{#if wiBefore}}{{wiBefore}}\n{{/if}}{{#if description}}{{description}}\n{{/if}}{{#if personality}}{{char}}'s personality: {{personality}}\n{{/if}}{{#if scenario}}Scenario: {{scenario}}\n{{/if}}{{#if wiAfter}}{{wiAfter}}\n{{/if}}{{#if persona}}{{persona}}\n{{/if}}";
          example_separator = "***";
          chat_start = "***";
          use_stop_strings = true;
          names_as_stop_strings = true;
          always_force_name2 = false;
        };
      };
      instruct."DS-R1-Qwen3-8B-ArliAI-RpR-v4-Small" = {
        json = {
          input_sequence = "<|im_start|>user";
          input_suffix = "<|im_end|>\n";
          output_sequence = "<|im_start|>assistant";
          output_suffix = "<|im_end|>\n";
          system_sequence = "<|im_start|>system";
          system_suffix = "<|im_end|>\n";
          stop_sequence = "<|im_end|>";
          wrap = true;
          macro = true;
          names_behavior = "none";
          sequences_as_stop_strings = true;
        };
      };
    };

    # ── Account state (settings.json) ───────────────────────────────────
    # Seeded into every account's settings.json and deep-merged over whatever
    # the server has already written.
    settings.common = {
      # power_user — the UI's "AI Response Configuration" overrides, applied
      # on every service start.
      power_user = {
        user_prompt_bias = "<think>";
        show_user_prompt_bias = true;
        always_force_name2 = false;
        # Which advanced-formatting template is active.
        context.preset = "DS-R1-Qwen3-8B-ArliAI-RpR-v4-Small";
        instruct = {
          preset = "DS-R1-Qwen3-8B-ArliAI-RpR-v4-Small";
          names_behavior = "none";
        };
        sysprompt.name = "DS-R1-Qwen3-8B-ArliAI-RpR-v4-Small";
        reasoning = {
          name = "DS-R1-Qwen3-8B-ArliAI-RpR-v4-Small";
          prefix = "<think>";
          suffix = "</think>";
          separator = "\n";
          auto_parse = true;
        };
        model_templates_mappings = {
          text = {
            context = "DS-R1-Qwen3-8B-ArliAI-RpR-v4-Small";
            instruct = "DS-R1-Qwen3-8B-ArliAI-RpR-v4-Small";
          };
        };
      };

      # extension_settings — per-extension state, plus the connection
      # manager's profiles (the model dropdown in the UI).
      extension_settings = {
        connectionManager = {
          profiles = [
            {
              id = "3f6b1c40-0f1a-4c62-9a2e-6d1f0a5b7c31";
              name = "DeepSeek R1 Qwen3";
              mode = "tc";
              api = "ollama";
              preset = "Reasoning";
              model = "hf.co/Lewdiculous/DS-R1-Qwen3-8B-ArliAI-RpR-v4-Small-GGUF-IQ-Imatrix:Q4_K_M-imat";
              api-url = "http://127.0.0.1:11434";
              sysprompt = "DS-R1-Qwen3-8B-ArliAI-RpR-v4-Small";
              sysprompt-state = "true";
              context = "DS-R1-Qwen3-8B-ArliAI-RpR-v4-Small";
              tokenizer = "best_match";
              reasoning-template = "DS-R1-Qwen3-8B-ArliAI-RpR-v4-Small";
              start-reply-with = "<think>";
            }
            {
              id = "9b2d4e77-51c8-4a03-8f6d-0c7e2b1a4d58";
              name = "InfinityRP";
              mode = "tc";
              api = "ollama";
              preset = "Default";
              model = "hf.co/Lewdiculous/InfinityRP-v1-7B-GGUF-IQ-Imatrix:Q4_K_M-imat";
              api-url = "http://127.0.0.1:11434";
              sysprompt = "Neutral - Chat";
              sysprompt-state = "true";
              context = "Default";
              tokenizer = "best_match";
              reasoning-template = "Think XML";
            }
          ];
          selectedProfile = "3f6b1c40-0f1a-4c62-9a2e-6d1f0a5b7c31";
        };

        # VectFox — the RAG extension. The extension itself is installed
        # through `extensions` below; this is only its settings.
        vectfox = {
          backend = "qdrant";
          qdrantUrl = "http://127.0.0.1:6333";
          qdrantGrpcUrl = "http://127.0.0.1:6334";
          embeddingProvider = "sillytavern";
        };

        # Built-in extensions
        idle = {
          enabled = false;
          timer = "20";
          useContinuation = false;
          useRegenerate = false;
          useImpersonation = false;
          useSwipe = false;
          repeats = 2;
          sendAs = "user";
          randomTime = false;
          timeMin = 60;
          includePrompt = false;
        };
        websearch = {
          source = "google";
          cacheLifetime = 604800;
          budget = 2000;
          position = 0;
          depth = 2;
          use_backticks = true;
          use_trigger_phrases = true;
          use_function_tool = false;
          searxng_url = "";
        };
        vrm = {
          enabled = true;
          follow_camera = true;
          tts_lips_sync = false;
          blink = true;
          auto_send_hitbox_message = true;
          lock_models = false;
        };
        accuweather = {
          provider = "accuweather";
          preferredLocation = "";
        };
      };
    };

    # ── Third-party extensions ───────────────────────────────────────────
    # Installed as pinned store paths under the package's third-party
    # directory; bump `rev` and rebuild to update.
    extensions = {
      # RAG / vector memory.
      VectFox = {
        url = "https://github.com/KritBlade/VectFox";
        rev = "5784a427ebeb6bae213a64740218bdf4ad05f97e";
      };

      "Extension-Idle" = {
        url = "https://github.com/SillyTavern/Extension-Idle";
        rev = "4225ff5d5078e4fc583d3e92d3cf78f487da715c";
      };
      "Extension-WebSearch" = {
        url = "https://github.com/SillyTavern/Extension-WebSearch";
        rev = "9c3aa6686289bdcf26e7664a4dc18a777215108b";
      };
      "Extension-VRM" = {
        url = "https://github.com/SillyTavern/Extension-VRM";
        rev = "2b4c4d015a40d255a064e83ed70c408046d58049";
      };
      "Extension-Weather" = {
        url = "https://github.com/SillyTavern/Extension-Weather";
        rev = "c169a3cacaefd032d2857417564e0330b516a1b3";
      };
    };
  };

  # ── TV & EPG ──────────────────────────────────────────────────────────
  my.services.xmltv = {
    enable = true;
    configure = {
      region = "64257";
      channelFormat = "number";
      channels = [
        # SD Channels (1-99)
        "1"
        "2"
        "3"
        "4"
        "5"
        "6"
        "8"
        "9"
        "10"
        "11"
        "12"
        "13"
        "14"
        "15"
        "16"
        "17"
        "18"
        "19"
        "20"
        "21"
        "22"
        "23"
        "25"
        "26"
        "27"
        "28"
        "29"
        "30"
        "31"
        "32"
        "33"
        "34"
        "35"
        "36"
        "37"
        "38"
        "39"
        "40"
        "41"
        "42"
        "43"
        "44"
        "45"
        "46"
        "47"
        "48"
        "49"
        "50"
        "51"
        "52"
        "56"
        "57"
        "58"
        "59"
        "60"
        "61"
        "62"
        "63"
        "64"
        "65"
        "66"
        "67"
        "68"
        "69"
        "70"
        "71"
        "72"
        "73"
        "74"
        "76"
        "78"
        "81"
        "82"
        "83"
        "84"
        "89"
        "90"
        "91"
        "92"
        "94"
        "95"
        "96"
        "97"
        "98"
        "99"
        # HD Channels (101+)
        "101"
        "102"
        "103"
        "104"
        "105"
        "106"
        "107"
        "201"
        "202"
        "203"
        "204"
        "205"
        "206"
        "207"
        "208"
        "209"
        "210"
        "231"
        "232"
        "233"
        "236"
        "250"
        "251"
        "252"
        "253"
        "254"
        "255"
        "256"
        "257"
        "259"
        "260"
        "261"
        "263"
        "264"
        "265"
        "266"
        "268"
        "269"
        "270"
        "271"
        "272"
        "273"
        "274"
        "275"
        "276"
        "278"
        "279"
        "283"
        "284"
        "287"
        "288"
        "289"
        "290"
        "291"
        "601"
        "700"
        "701"
        "702"
        "703"
        "704"
        "705"
        "706"
        "707"
        "708"
        "709"
        "710"
        "711"
        "712"
        "713"
        "714"
        "716"
        "718"
        "723"
        "724"
        "725"
        "728"
        "730"
        "731"
        "732"
      ];
    };
    days = 7;
    extraArgs = [ "--fast" ];
    serveViaHttp = true;
    httpPort = 8889;
  };

  # ── Media Stack (*arr) ─────────────────────────────────────────────────
  my.services.jellyfin.mediaDirs = [ "/mnt/media" ];
  my.services.prowlarr.indexers = [
    {
      name = "SpeedCD";
      implementation = "SpeedCD";
      settings = [
        { name = "baseUrl"; value = "https://speed.cd/"; }
        { name = "username"; value = "ppextendo"; }
        { name = "password"; credentialFile = config.age.secrets."speed-cd-password".path; }
      ];
    }
  ];

  # ── Manga Reader ─────────────────────────────────────────────────────────
  # Suwayomi-Server backend + Moku frontend (both enabled via entertainment profile)
  # Moku connects to the server's Suwayomi instance over Tailscale
  # Temporarily disabled (2026-09-22): the moku Tauri build is heavy on every
  # nix run; re-enable by deleting this override once the system rebuild is done.
  # (modules/nixos/moku.nix already bumped to fetchPnpmDeps fetcherVersion 4.)
  my.programs.moku.enable = false;
  my.programs.moku.serverUrl = "http://100.78.102.28:4567/suwayomi";
  my.services.suwayomi = {
    # F11: extensionRepos, sync.export.{enable,autoPush,repoPath,secretPath}, sync.import.enable
    # now module defaults (suwayomi/sync-options.nix) — invariant core duplicated desktop/server removed
    settings.server = {
      # backupInterval is a FREEFORM HOCON field (options.nix freeformType) — cannot carry a
      # module default, so it stays explicit here (recon F11)
      backupInterval = 0;
    };
    openFirewall = true;
    extraReadWritePaths = [ "/mnt/media/suwayomi" ];
    sync.export.interval = "hourly"; # F11: divergent — desktop hourly vs server daily (recon F11)
  };

  # Only the desktop manages tailscale ACL policy (auth keys, port grants)
  my.services.tailscale = {
    acceptRoutes = true;
    manager = {
      enable = true;
      # tcp:9100: allow server's Prometheus to scrape desktop's node-exporter.
      # (This explicit list overrides the common.nix mkDefault, so tcp:9100
      # must be listed here to take effect.)
      policy.interNodePorts = [ "tcp:22" "tcp:4567" "tcp:9100" ];
    };
  };

  # ── Monitoring ─────────────────────────────────────────────────────────
  # Expose node-exporter metrics so the server's Prometheus can scrape them
  # over the tailnet. openFirewall opens tcp:9100 in the NixOS firewall.
  my.services.monitoring = {
    enable = true;
    nodeExporter = {
      openFirewall = true;
    };
  };

  # Self-healing tailnet data plane: restart tailscaled when an online peer stops
  # answering through-tunnel pings (the documented "data-plane wedge" — local
  # interface/MTU/self-ping all look fine while every TCP connection times out).
  my.services.tailscaleWatchdog = {
    enable = false; # DISABLED 2026-09-15: server is down, pinging 100.78.102.28 spams degradation emails
    canaryPeers = [ "100.78.102.28" "100.70.43.44" ]; # server, pikvm
  };

  # ── ZeroTier (Tailscale-independent fallback mesh) ─────────────────────
  # Same networks as the server: HomeServer (mesh fallback) + Gaming
  # (LAN-style game sessions). Always-on at boot (wantedBy = multi-user.target,
  # see modules/nixos/zerotier/config.nix). The tailscale-watchdog only alerts,
  # it does not start/stop this service.
  my.services.zerotier = {
    enable = true;
    networks = [ "1c33c1ced07e2ece" "363c67c55ab5da47" ];
  };

  # Trust the ZeroTier interface so LAN-style gaming sessions (e.g. the
  # Prism Launcher Minecraft server on :25565) are reachable from other mesh
  # peers without listing each port. Same pattern the tailscale module uses
  # for tailscale0 (modules/nixos/tailscale/config.nix).
  networking.firewall.trustedInterfaces = [ "zt6ntnehy5" ];

  # Clamp TCP MSS on both mesh tunnels (tailscale0 + zt6ntnehy5). The desktop
  # hosts the LAN-style Minecraft session; ZeroTier peers behind small-MTU /
  # lossy paths (e.g. the ~1200B blackhole measured to 172.23.98.176) stall and
  # time out during the game's configuration phase unless MSS is clamped.
  # Default mss (1140) fits the measured path. Same module as the server host.
  my.services.mssClamp = {
    enable = true;
    interfaces = [ "tailscale0" "zt6ntnehy5" ];
  };

  my.services.ollama = {
    enable = true;
    gpu.enable = true;
    gpu.type = "amd";
    dataDir = "/mnt/data/ollama";
  };

  # ── AI Desktop App ──────────────────────────────────────────────────────────
  my.services.jan = {
    enable = true;
    apiServer.enable = true;
    ollama.enable = true;
  };

  # T3: my.services.chatterbox-tts.enable = false removed (recon H9) — mkEnableOption
  #     default is already false (chatterbox-tts/options.nix:4), so this was redundant.

  # mosh client — pair with server's my.services.mosh for lag-free sessions
  # over the flaky Scotland→Texas tailnet path (UDP, survives relay flaps).
  environment.systemPackages = with pkgs; [ mosh ntfs3g ];

  # ── Vulkan environment ──────────────────────────────────────────────────
  # Disable Steam's Fossilize layer globally — it deadlocks with RADV during
  # heavy Vulkan pipeline compilation (Satisfactory, Overwatch, etc.).
  # Fossilize is an implicit layer loaded by Pressure Vessel, so
  # VK_LAYER_DISABLE alone isn't enough; we also set STEAM_FOSSILIZE_DUMP_PATH
  # to /dev/null to prevent recording, and disable threaded GL to avoid
  # multi-threaded pipeline deadlocks.
  environment.sessionVariables = {
    VK_LAYER_DISABLE = "Fossilize";
    STEAM_FOSSILIZE_DUMP_PATH = "/dev/null";
    __GL_THREADED_OPTIMIZATIONS = "0";
  };

  # Music playlists live on the server host (configurations/nixos/server) —
  # not here; desktop previously enabled them and music-install-funky failed.

  # ── Home Manager Extra ───────────────────────────────────────────────────
  my.homeManager.extraConfig = {
    my.programs = {
      # F10-desktop: discord/firefox/obsidian/thunderbird/vscode already mkDefault'd by
      # homeProfiles.desktop (profiles/home/config.nix:26-38) — only genuinely per-host
      # extras kept below. localsend/whatsapp-electron/youtube-music + direnv spotify
      # secretFiles moved to homeProfiles.desktop (recon D2/D3).

      # Obsidian: point the pre-registered vault at the REAL vault dir (module default
      # is "Documents/Obsidian_Vault" underscore; the actual dir is "Obsidian Vault" with
      # a space) and git-back it from the private Cairns-Notes repo. On the first
      # activation after this change the module removes the empty local dir and clones.
      obsidian = {
        defaultDirectory = "Documents/Obsidian Vault";

        # Local REST API with MCP: backs the obsidian MCP server (declared in the
        # vault's .opencode/opencode.json) and Obsidian's own /mcp/ endpoint.
        # `.obsidian/` is gitignored in the vault, so the plugin is pinned here
        # to keep the install reproducible. Bump version + all three hashes
        # together; the manifest version mismatch triggers a reinstall.
        plugins."obsidian-local-rest-api" = {
          enable = true;
          version = "5.5.2";
          repo = "coddingtonbear/obsidian-local-rest-api";
          mainJsHash = "sha256-kElLZETF/t5dEvlzRqq4OSZbXHoJUg/oe078IjYLbNg=";
          manifestHash = "sha256-LORt+h7pthUN2N0NvMaGNu4V1UM/mj+iTptsyERuviU=";
          stylesHash = "sha256-GZVt6vTRQUI4H4H9+SyugkH9CqCKGjpUZLDQB7rhkk0=";
        };

        repo = {
          enable = true;
          url = "https://github.com/Cairnstew/Cairns-Notes";
          tokenFile = config.age.secrets."github-token-obsidian".path;
        };
      };

      # Recordings go to the 500GB data SSD (374G free) instead of the home
      # directory. OBS's Linux default is $HOME; the module patches the path
      # into every profile on activation, so restart OBS to pick it up.
      "obs-studio" = {
        recordingPath = "/mnt/data/obs-recordings";

        # OBS 32.2.2 SIGSEGVs in linux-pipewire's Screencast `start()` when the
        # portal selection response arrives (upstream #13809; Hyprland/wlroots
        # buffer path also hits #13318). wlrobs uses wlr-screencopy directly and
        # bypasses the portal: add "Wayland output(scpy)" instead of the PipeWire
        # sources. Use scpy, not dmabuf — dmabuf crashes in libwlrobs
        # (`wl_proxy_marshal_constructor`; wlrobs-hg breaks on OBS 31.1.2+).
        plugins = [ pkgs.obs-studio-plugins.wlrobs ];
      };

      squidProxyClient = {
        enable = true;
        proxyPasswordFile = config.age.secrets."squid-htpasswd".path;
      };

      # Balatro multiplayer (base enabled via gaming profile; opt-in to multiplayer here)
      balatro.enable = true;
      balatro.multiplayer.enable = true;

      # Prism Launcher data (instances, libraries, assets) on the external media
      # drive to keep the system SSD free.
      minecraft.dataDir = "/mnt/media/Modding/PrismLauncher";

      # Client instances built from the repo's packwiz modpacks (same packs the
      # server runs). Each key is a modpack name (matches the modpacks/ dir); a
      # systemd timer rebuilds the instance from its pack definition and
      # installs it into Prism.
      minecraft.instances.AllTheTech = {
        enable = true;
        server = "server.tail685690.ts.net:25565";
      };

      # Modpack engineering tooling (Modrinth MCP lookup). Mod jars live next to
      # Prism Launcher data on the media drive.
      modpack = {
        enable = true;
        modsDir = "/mnt/media/Modding/mods";
      };

      # VNC viewer for the server's remote-gui virtual display (Prism Launcher
      # headless on Xvfb, shared via x11vnc). Connect with `vnc-server` or the
      # "VNC: server" desktop entry.
      vncviewer = {
        enable = true;
        connections.server = {
          host = "server.tail685690.ts.net";
          port = 5900;
        };
      };
    };

    # GNOME-specific extras removed: host-info extension (broken/unused),
    # dconf shell settings, and gnome-monitor-config service (replaced by my.monitors)

    # ── Sieve mail filtering (mbsync + pigeonhole sieve-filter) ───────────────
    # Gmail app password comes from /run/agenix/mcp-better-email-password
    # (verified working for IMAP 2026-09-29). Add the same block to laptop to
    # enable there too.
    my.services.mailFilter = {
      enable = true;
    };
  };

}
