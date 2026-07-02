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
    memory = 4096;
    cores = 4;
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
      my.testing = {
        enable = true;
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
    development.enable = true;
    entertainment.enable = true;
    gpu.mesa.enable = true;
    location.enable = true;
    gaming.enable = true;
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

  # ── Desktop Environment ────────────────────────────────────────────────────
  # Toggle between "hyprland" and "gnome" to switch desktop environments.
  my.profiles.desktop.choice = "hyprland";
  # my.profiles.desktop.choice = "gnome";

  # ── Monitor Layout ─────────────────────────────────────────────────────────
  # DP-1: 2560×1440 @ 120Hz (center, primary)
  # DP-3: 1920×1200 @ 60Hz (left, portrait) — Dell U2412M
  # DP-2: 1920×1200 @ 60Hz (right, portrait) — Dell U2412M
  my.monitors = [
    {
      name = "DP-3";
      width = 1920;
      height = 1200;
      refreshRate = 60;
      x = 0;
      y = 0;
      transform = 3;
      workspace = "2";
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
      x = 3760;
      y = 0;
      transform = 1;
      workspace = "3";
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

      windowOpacity = {
        enable = true;
        focused = 0.93;
        unfocused = 0.80;
      };

      debug.enable = true;
      accelProfile = "flat";
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
  };

  my.programs.proton.ge.enable = true;

  my.programs.steam = {
    shaderPreCaching.enable = true;
    gamemode.enable = true;
    games.overwatch-2 = {
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
  };

  my.homeProfiles = {
    common.enable = true;
    desktop.enable = true;
    development.enable = true;
  };

  # ── Location ────────────────────────────────────────────────────────────
  my.system.location = {
    enable = true;  # M1: was missing — module wraps config in mkIf cfg.enable (default false)
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

  # ── Email alerts ─────────────────────────────────────────────────────────
  my.services.emailAlerts.enable = true;

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
  services.sillytavern = {
    enable = true;

    # Data directory — use upstream default /var/lib/SillyTavern matching ST's XDG path

    # Server
    port = 8000;
    whitelistMode = false;

    # Extensions: disable auto-update (extensions are declarative from Nix store, no .git)
    extensions.autoUpdate = false;

    # Text completion presets
    # Settings from model card: https://huggingface.co/ArliAI/DS-R1-Qwen3-8B-ArliAI-RpR-v4-Small
    # RpR models don't work well with repetition penalty samplers (XTC, DRY, rep_pen).
    textCompletionPresets = {
      Reasoning = {
        temp = 1.0;
        top_k = 40;
        top_p = 1.0;
        min_p = 0.02;
        do_sample = true;
        include_reasoning = true;
        genamt = 2048;
        rep_pen = 1.0;
        default = true;
      };
    };

    # Connection profiles for Ollama models
    connectionProfiles = {
      "DeepSeek R1 Qwen3" = {
        default = true;
        mode = "tc";
        api = "ollama";
        preset = "Reasoning";
        model = "hf.co/Lewdiculous/DS-R1-Qwen3-8B-ArliAI-RpR-v4-Small-GGUF-IQ-Imatrix:Q4_K_M-imat";
        apiUrl = "http://127.0.0.1:11434";
        sysprompt = "DS-R1-Qwen3-8B-ArliAI-RpR-v4-Small";
        syspromptState = true;
        context = "DS-R1-Qwen3-8B-ArliAI-RpR-v4-Small";
        tokenizer = "best_match";
        reasoningTemplate = "DS-R1-Qwen3-8B-ArliAI-RpR-v4-Small";
        startReplyWith = "<think>";
      };
      InfinityRP = {
        mode = "tc";
        api = "ollama";
        preset = "Default";
        model = "hf.co/Lewdiculous/InfinityRP-v1-7B-GGUF-IQ-Imatrix:Q4_K_M-imat";
        apiUrl = "http://127.0.0.1:11434";
        sysprompt = "Neutral - Chat";
        syspromptState = true;
        context = "Default";
        tokenizer = "best_match";
        reasoningTemplate = "Think XML";
      };
    };

    # Advanced formatting presets — named after the ArliAI RpR v4 model
    # https://huggingface.co/ArliAI/DS-R1-Qwen3-8B-ArliAI-RpR-v4-Small
    # Note: separator must match what the model actually outputs between </think> and response.
    # The model outputs a single newline, so separator is "\n" (not "\n\n").
    advancedFormatting = {
      reasoning = {
        "DS-R1-Qwen3-8B-ArliAI-RpR-v4-Small" = {
          prefix = "<think>";
          suffix = "</think>";
          separator = "\n";
          default = true;
        };
      };
      sysprompt = {
        "DS-R1-Qwen3-8B-ArliAI-RpR-v4-Small" = {
          content = ''
            You are a roleplaying AI with deep reasoning capabilities, based on the ArliAI RpR v4 model. Use <think> </think> tags for internal reasoning before responding. Stay in character and write creatively, responding from {{char}}'s perspective. Follow the character description and scenario closely.'';
          default = true;
        };
      };
      context = {
        "DS-R1-Qwen3-8B-ArliAI-RpR-v4-Small" = {
          story_string = "{{#if system}}{{system}}\n{{/if}}{{#if wiBefore}}{{wiBefore}}\n{{/if}}{{#if description}}{{description}}\n{{/if}}{{#if personality}}{{char}}'s personality: {{personality}}\n{{/if}}{{#if scenario}}Scenario: {{scenario}}\n{{/if}}{{#if wiAfter}}{{wiAfter}}\n{{/if}}{{#if persona}}{{persona}}\n{{/if}}";
          example_separator = "***";
          chat_start = "***";
          use_stop_strings = true;
          names_as_stop_strings = true;
          always_force_name2 = false;
          default = true;
        };
      };
      instruct = {
        "DS-R1-Qwen3-8B-ArliAI-RpR-v4-Small" = {
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
          default = true;
        };
      };
    };

    # User settings — power_user overrides applied on every service start
    userSettings = {
      enable = true;
      user_prompt_bias = "<think>";
      show_user_prompt_bias = true;
      # Force runtime settings that ST doesn't pick up from template files alone
      extraSettings = {
        always_force_name2 = false;
        instruct = {
          names_behavior = "none";
        };
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
    };

    # TTS settings — select Resemble provider with cluster and voices
    extraExtensionSettings = {
      tts = {
        currentProvider = "Resemble";
        Resemble = {
          cluster = "p";
          voices = [
            { name = "Default"; voice_id = "8bc27ed9"; }
            { name = "female"; voice_id = "8bc27ed9"; }
            { name = "male"; voice_id = "8bc27ed9"; }
          ];
        };
      };
    };

    # Declared extensions
    declaredExtensions = {
      # VectFox is bundled into the package — just set its settings
      vectfox = {
        enable = true;
        settings = {
          backend = "qdrant";
          qdrantUrl = "http://127.0.0.1:6333";
          qdrantGrpcUrl = "http://127.0.0.1:6334";
          embeddingProvider = "sillytavern";
        };
      };

      # Built-in extensions
      idle = {
        settings = {
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
      };
      websearch = {
        settings = {
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
      };
      vrm = {
        settings = {
          enabled = true;
          follow_camera = true;
          tts_lips_sync = false;
          blink = true;
          auto_send_hitbox_message = true;
          lock_models = false;
        };
      };
      accuweather = {
        settings = {
          provider = "accuweather";
          preferredLocation = "";
        };
      };

      # Third-party extensions from GitHub
      "Extension-Idle" = {
        enable = true;
        source = pkgs.fetchFromGitHub {
          owner = "SillyTavern";
          repo = "SillyTavern";
          rev = "4225ff5d5078e4fc583d3e92d3cf78f487da715c";
          hash = "sha256-gaAUQhYnAHWMKH67gNxlwYkOsQPRKOvjtsS7QisUBOU=";
        };
      };
      "Extension-WebSearch" = {
        enable = true;
        source = pkgs.fetchFromGitHub {
          owner = "SillyTavern";
          repo = "SillyTavern";
          rev = "9c3aa6686289bdcf26e7664a4dc18a777215108b";
          hash = "sha256-7TcR/cJUDnv5CIsSgwmSpFGG/lFeuMicXBdqCtVFH8c=";
        };
      };
      "Extension-VRM" = {
        enable = true;
        source = pkgs.fetchFromGitHub {
          owner = "SillyTavern";
          repo = "SillyTavern";
          rev = "2b4c4d015a40d255a064e83ed70c408046d58049";
          hash = "sha256-1WxCbkdt9k4JAF2+CNozDgZfdgoHF0vEzAjAyIHXUM0=";
        };
      };
      "Extension-Weather" = {
        enable = true;
        source = pkgs.fetchFromGitHub {
          owner = "SillyTavern";
          repo = "SillyTavern";
          rev = "c169a3cacaefd032d2857417564e0330b516a1b3";
          hash = "sha256-kLJW803iMsnZ4iLEviS22w0qEdXb40EejKbzmajfZi4=";
        };
      };
    };
  };

  # ── Manga Reader ─────────────────────────────────────────────────────────
  # Suwayomi-Server backend + Moku frontend (both enabled via entertainment profile)
  my.services.suwayomi = {
    autoBindTailscaleIp = true;
    settings.server = {
      backupInterval = 0;
      extensionRepos = [
        "https://raw.githubusercontent.com/keiyoushi/extensions/repo/index.min.json"
      ];
    };
    openFirewall = true;
    extraReadWritePaths = [ "/mnt/media/suwayomi" ];
    sync.export = {
      enable = true;
      autoPush = true;
      repoPath = "/home/seanc/nixos-config";
      secretPath = "/run/agenix/github-token";
      interval = "hourly";
    };
    sync.import.enable = true;
  };

  # Only the desktop manages tailscale ACL policy (auth keys, port grants)
  my.services.tailscale = {
    acceptRoutes = true;
    manager = {
      enable = true;
      policy.interNodePorts = [ "tcp:22" "tcp:4567" ];
    };
  };

  my.services.ollama = {
    enable = true;
    gpu.enable = true;
    gpu.type = "amd";
    dataDir = "/mnt/data/ollama";
  };

  my.services.chatterbox-tts.enable = false;

  environment.systemPackages = with pkgs; [ ntfs3g ];

  # ── Home Manager Extra ───────────────────────────────────────────────────
  my.homeManager.extraConfig = {
    my.programs.direnv.secretFiles.spotify = {
      paths = {
        SPOTIFY_CRED = config.age.secrets."spotify-cred".path;
      };
    };
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
