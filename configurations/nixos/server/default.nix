{ flake, lib, config, pkgs, ... }:
{
  imports = [
    ./configuration.nix
    ./hardware-configuration.nix
    ./disk-config.nix
    flake.inputs.self.nixosModules.common
  ];

  # ── System Identity ──────────────────────────────────────────────────────
  networking.hostName = "server";
  nixos-unified.sshTarget = "seanc@server";

  # ── State Version ────────────────────────────────────────────────────────
  # Must match the nixpkgs version this was first installed with
  system.stateVersion = "24.05";

  # ── System Profiles ──────────────────────────────────────────────────────
  my.profiles = {
    server.enable = true;
    # ai.enable disabled 2026-09-01 (ComfyUI priority): the AI LLM stack
    # (Ollama, RisuAI, Open WebUI, Letta) is paused so ComfyUI gets the whole
    # GPU for image generation. Re-enable with `ai.enable = true` plus
    # `my.services.ollama.enable = true` (the ai profile asserts Ollama).
    ai.enable = false;
    gpu.nvidia-headless.enable = true;
    location.enable = true;
  };

  # ── Hardening CPU quotas — only list units that actually exist ─────────
  # The hardened default cpuQuota references docker-ollama/podman-ollama/
  # jellyfin; hardening mapAttrs' CREATES a unit definition for every name in
  # the list, so with the AI stack paused it shipped a docker-ollama unit with
  # no ExecStart — systemd refused it and `nix run .#activate` exited 4
  # ("Service has no ExecStart="). comfy-ui is kept: it is the live heavy
  # service and the 400% cap keeps SSH responsive during image generation.
  my.system.hardening.cpuQuota = {
    "comfy-ui" = "400%";
  };

  # ── VS Code Server ──────────────────────────────────────────────────────
  # Enables Remote-SSH on NixOS (patches dynamically linked Node binaries)
  my.programs.vscode.server.enable = true;

  # ── Home Profiles ────────────────────────────────────────────────────────
  my.homeProfiles = {
    common.enable = true;
    server.enable = true;
    development.enable = true;
  };

  # ── Home Manager Extra ───────────────────────────────────────────────────
  my.homeManager.extraConfig.my.programs.goals.enable = true;
  # CV content MCP server — thin CRUD over the Cairnstew/CV sqlite store
  # (same host as goals; the always-on headless box with opencode-web).
  my.homeManager.extraConfig.my.programs.cv.enable = true;
  # Prism Launcher (Minecraft client) — launcher defaults to prismlauncher,
  # data dir on the large SATA drive to keep NVMe free.
  my.homeManager.extraConfig.my.programs.minecraft = {
    enable = true;
    dataDir = "/mnt/data/prismlauncher";
  };

  # ── Remote GUI (Prism Launcher on a virtual display) ──────────────────────
  # Runs the launcher's GUI headlessly on Xvfb :10, shared via x11vnc so it can
  # be viewed from the desktop host over the tailnet. No firewall change needed
  # (tailscale0 is trusted). Connect with any VNC client:
  #   vncviewer server.tail685690.ts.net:5900   (or GNOME Connections)
  my.services.remoteGui = {
    enable = true;
    windowManager = pkgs.openbox; # decorations + focus for the launcher window
    apps.prismlauncher = {
      command = "${pkgs.prismlauncher}/bin/prismlauncher --dir /mnt/data/prismlauncher";
      user = "seanc";
    };
  };
  # Terminal opencode must not run while the browser (web) session is live —
  # both share ~/.config/opencode and the ensemble DB. Gate both directions.
  my.homeManager.extraConfig.my.programs.opencode.sessionGate.enable = true;

  # ── Learning-promoter watcher ──────────────────────────────────────────────
  # Auto-dispatch the promoter agent via opencode serve when proposed learnings
  # exist. Checks every 1min; reconciles partial/stale verdicts; uses API-based
  # communication (no tmux). Requires opencode-serve.service (auto-started).
  # DISABLED 2026-08-25 (user decision): learnings accumulate in the queue and
  # are processed only on demand via a manual `/learning-promote` dispatch.
  # Re-enable by flipping this to true and rebuilding — see
  # modules/home/opencode/options.nix learningPromoterWatcher.* for tuning.
  my.homeManager.extraConfig.my.programs.opencode.learningPromoterWatcher.enable = false;

  # ── Location ─────────────────────────────────────────────────────────────
  my.system.location = {
    # enable = true — redundant: profile already sets via mkIf cfg.location.enable (M3)
    timeZone = "America/Chicago";
    latitude = 30.2672;
    longitude = -97.7431;
  };

  # ── Networking ──────────────────────────────────────────────────────────
  networking.networkmanager.enable = true;

  # ── Reverse Proxy ─────────────────────────────────────────────────────
  # Unified proxy module: services auto-register with my.services.proxy.upstreams.
  # tailscale serve forwards :443 → caddy:8081 so each service is at
  # https://server.tail685690.ts.net/<service>/.
  # Dashboard at / shows all registered services.
  my.services.proxy = {
    # F4: proxy.enable is common.nix mkDefault true — redundant here (recon F4)
    # F5: listenAddresses [ "127.0.0.1" ] is the proxy/options.nix default — redundant here (recon F5)
    tailscaleServe.enable = true;

    # OpenCode Go usage bars on the dashboard — reads the snapshot written by
    # seanc's opencode-go-usage systemd user timer (every 5 min).
    systemMetrics.opencodeGo.usageJsonFile =
      "/home/seanc/.cache/opencode/go-usage.json";
  };

  # ── Monitoring ─────────────────────────────────────────────────────────
  # Prometheus collects node-exporter metrics from this host and the
  # desktop (100.121.125.58); Grafana is served at /grafana behind Caddy.
  # Grafana binds 3001 (3000 is used by open-webui via the ai profile).
  my.services.monitoring = {
    enable = true;
    prometheus = {
      enable = true;
      scrapeTargets = [ "100.121.125.58:9100" ]; # desktop node-exporter
    };
    grafana = {
      enable = true;
      rootUrl = "https://server.tail685690.ts.net/grafana/";
    };
  };

  # ── Backup Target ──────────────────────────────────────────────────────
  # Hosts restic repositories for desktop/laptop under /mnt/data/backup
  # (SFTP-chrooted over tailnet SSH port 22 — no new ports). Each source's
  # subdirectory is pre-provisioned here; public keys are filled in once the
  # shared backup-ssh-key is generated (Tier 1 secrets step).
  my.services.backup-target = {
    enable = true;
    sources = {
      desktop = {
        publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBeutWkI0m3IvLKyb67OoKQ/q6CKAgeEtd43+kAi6X2C backup@nixos";
      };
      laptop = {
        publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBeutWkI0m3IvLKyb67OoKQ/q6CKAgeEtd43+kAi6X2C backup@nixos";
      };
    };
  };

  # ── Container Storage ──────────────────────────────────────────────────
  # Store container images and volumes on the large SATA data drive (1.8T)
  # to preserve NVMe space for the Nix store and OS.
  my.virtualisation.docker.dataRoot = "/mnt/data/docker-data";

  virtualisation.containers.storage.settings.storage = {
    graphroot = "/mnt/data/containers/storage";
  };

  # ── Nix Build Directory ─────────────────────────────────────────────────
  # Use the large SATA data disk (1.8T) for build temp files to preserve
  # NVMe space for the Nix store and OS.
  nix.settings.build-dir = "/mnt/data/nix-build";

  # Ensure the build directory exists before nix tries to use it
  systemd.tmpfiles.rules = [ "d /mnt/data/nix-build 0755 root root -" ];

  # ── Networking / VPN (Dual-Mesh for Headless Reliability) ──────────────
  # Both Tailscale and ZeroTier run simultaneously so you always have a
  # fallback if one mesh goes down — critical for a completely headless box.

  my.services.tailscale = {
    mtu = 1200;
    tags = [ "tag:nixos" "tag:temp" ];
    acceptRoutes = true;
    manager.enable = true;
  };

  # ZeroTier is a Tailscale-independent fallback mesh — always-on at boot
  # (wantedBy = multi-user.target, see modules/nixos/zerotier/config.nix).
  # The tailscale-watchdog does NOT start/stop it anymore; it only alerts.
  my.services.zerotier = {
    enable = true;
    # HomeServer (mesh fallback) + Gaming (LAN-style game sessions).
    # These are joined by zerotierone-joinNetworks on service start.
    networks = [ "1c33c1ced07e2ece" "363c67c55ab5da47" ];
  };

  # Email alerts: provides send-alert command for system notifications
  my.services.emailAlerts.enable = true;

  # Tailscale watchdog: monitors connectivity, starts zerotier on failure, alerts via email
  my.services.tailscaleWatchdog = {
    enable = true;
    canaryPeers = [ "100.121.125.58" "100.70.43.44" ]; # desktop, pikvm
  };

  # ── SSH Resilience Stack ─────────────────────────────────────────────────
  # MSS clamping: root-cause fix for the MTU blackhole (tailscaled resets
  # tailscale0 to 1280 on restart; this clamps TCP MSS on the tunnel so large
  # packets survive instead of being silently dropped while ping still works).
  # MSS auto-derived: tailscale mtu 1200 → 1140.
  my.services.mssClamp.enable = true;

  # mosh + tmux: sessions survive mesh/VPN restarts (mosh rides UDP and
  # reconnects when the mesh comes back). openFirewall lets it work over the
  # ZeroTier/LAN fallback too, not just the (trusted) tailnet.
  my.services.mosh = {
    enable = true;
    openFirewall = true;
  };

  # Tor onion-service SSH: zero-inbound-port last resort. Works when both
  # meshes AND all inbound connectivity fail. Address: cat /var/lib/tor/onion/ssh/hostname
  my.services.torSsh.enable = true;

  # ttyd web console: browser-based emergency shell. Bound to the ZeroTier IP
  # so it's reachable even when Tailscale is down (basic auth protects it).
  my.services.ttyd = {
    enable = true;
    address = "192.168.191.54"; # ZeroTier IP (zt2lr37ya6) — Tailscale-independent path
    username = "seanc";
    passwordFile = config.age.secrets."ttyd-password".path;
    openFirewall = true; # listener binds only to the ZT IP, so this is ZT-scoped
  };
  my.services.proxy.upstreams.ttyd.host = "192.168.191.54"; # Caddy → ttyd on ZT IP

  # autossh phone-home reverse tunnel: reach this box via plain internet SSH
  # even when every mesh is down. Requires a bastion host you own — uncomment
  # and set `bastion` once you have one:
  # my.services.autosshReverse = {
  #   enable = true;
  #   bastion = "seanc@bastion.example.com";
  # };

  # ── SSH (LAN Password Fallback) ──────────────────────────────────────
  # Primary: SSH keys via Tailscale SSH + ZeroTier
  # Fallback: Password auth from LAN subnets (for physical access)
  # Tailscale uses 100.64.0.0/10 = not matched; ZeroTier may overlap with
  # private ranges so be specific about your actual LAN subnet.
  my.services.ssh.lanSubnets = [ "192.168.0.0/16" "172.16.0.0/12" ];

  # Boot resilience: Emergency alerting, boot health tracking
  my.services.bootAlerting.enable = true;
  my.services.bootHealth = {
    enable = true;
    autoRollback.enable = true;
  };

  # ── ComfyUI (AI Image Generation) ───────────────────────────────────────
  # Primary GPU workload on this box (RTX 3060 12GB): node-based diffusion /
  # image generation. Ollama + the AI LLM frontends are disabled above so
  # ComfyUI has the GPU to itself. Accessible at
  # https://server.tail685690.ts.net/comfyui/ (proxy upstream registered by
  # the module) and directly on LAN :8188.
  #
  # ComfyUI-Manager is enabled as the `comfyui_manager` PYTHON PACKAGE (the
  # only install method ComfyUI 0.25.x accepts — it checks find_spec and
  # silently disables --enable-manager when the package is absent). The module
  # builds it from the pinned 4.2.2 release tag (main lags at 3.41 and fails
  # the frontend's >= 4.2.1 check) and injects it via PYTHONPATH. Do NOT list
  # the Manager under `customNodes` — that path is legacy and fails to import
  # on 4.x.
  my.services.comfyui = {
    # enable is explicit now that profiles/system/ai.nix no longer supplies it
    enable = true;
    listenHost = "0.0.0.0"; # tailscale-serve + LAN access
    port = 8188;
    dataDir = "/mnt/data/comfyui";

    enableManager = true; # --enable-manager + comfyui_manager python package

    # Curated custom nodes from the module's pinned catalog (see
    # modules/nixos/ai/comfyui/catalog.nix). Every entry is a locked
    # url+rev+sha256 fetch — pure `nix run .#activate` safe.
    # - workflow/QoL: Comfyroll, pythongosssss, cubiq essentials, WAS suite,
    #   rgthree, Image-Saver (Civitai-metadata), Lora trigger words
    # - detailers: Impact Pack + Subpack + Inspire
    # - upscale/layers/photo: Ultimate SD Upscale, LayerStyle
    # - conditioning: ControlNet aux preprocessors, Advanced ControlNet,
    #   IPAdapter plus
    # - video: AnimateDiff Evolved, VideoHelperSuite, KJNodes
    # - captioning: Florence2, WD14 Tagger
    # - quantized loading: GGUF
    # - CivitAI: official orchestration pack (civitai-comfy-nodes), authenticated
    #   with the agenix `civitai-key` secret via comfy-ui-civitai-auth. The
    #   legacy `civitai_comfy_nodes` pack was removed — deprecated upstream and
    #   superseded by the official pack.
    presets = [
      "ComfyUI_Comfyroll_CustomNodes"
      "ComfyUI-Custom-Scripts"
      "ComfyUI_essentials"
      "was-node-suite-comfyui"
      "rgthree-comfy"
      "ComfyUI-Image-Saver"
      "ComfyUI-Lora-Auto-Trigger-Words"
      "ComfyUI-Impact-Pack"
      "ComfyUI-Impact-Subpack"
      "ComfyUI-Inspire-Pack"
      "ComfyUI_UltimateSDUpscale"
      "ComfyUI_LayerStyle"
      "comfyui_controlnet_aux"
      "ComfyUI-Advanced-ControlNet"
      "ComfyUI_IPAdapter_plus"
      "ComfyUI-AnimateDiff-Evolved"
      "ComfyUI-VideoHelperSuite"
      "ComfyUI-KJNodes"
      "ComfyUI-Florence2"
      "ComfyUI-WD14-Tagger"
      "ComfyUI-GGUF"
      "civitai-comfy-nodes"
    ];
    # Civitai API key for the official civitai-comfy-nodes pack (registered
    # automatically on boot by comfy-ui-civitai-auth).
    civitaiApiKeyPath = config.age.secrets."civitai-key".path;

    # Declarative models.
    #
    # Krea 2 TURBO — DIFFUSION-MODEL-ONLY (no TE/VAE inside; CheckpointLoaderSimple
    # can never load it), loaded via UNETLoader from models/diffusion_models/.
    # The URN's civitai fileId is what is on disk (sha256 matches), but the URN
    # <type> "checkpoint" would map to checkpoints/ — the folder is forced to
    # "diffusion_models" so we verify in place. The file was manually placed at
    # /mnt/data/comfyui/models/diffusion_models/krea2TurboFP8_krea2TURBO.safetensors
    # (12.9 GB, raw FP8 E4M3, metadata krea2_fp8: true); download mode verifies
    # the sha256 and only re-fetches if the file is missing/mismatched.
    models = {
      "krea2TurboFP8_krea2TURBO.safetensors" = {
        urn = "urn:air:krea2:checkpoint:civitai:2723583@3060999+2939623";
        type = "diffusion_models";
        sha256 = "0kpn616i57djdz1ib2851jjrf4jrnjws3jafbmg9dpsrgi826d9d";
      };
      # Krea 2 text encoder (Qwen3-VL 4B, FP8 scaled) — required for
      # CLIPLoader(type="krea2") text conditioning. From the official
      # Comfy-Org/Krea-2 HF repo (not gated); download mode puts the real file
      # in models/text_encoders/ on the data disk (dir created by the module).
      "qwen3vl_4b_fp8_scaled.safetensors" = {
        url = "https://huggingface.co/Comfy-Org/Krea-2/resolve/main/text_encoders/qwen3vl_4b_fp8_scaled.safetensors";
        type = "text_encoders";
        mode = "download";
        sha256 = "153hm169glmxf0js9rban2hla52jdf1cppyadkfjbg0bvx253gal";
      };
      # Krea 2 VAE (Qwen image VAE) — VAELoader(qwen_image_vae) required for
      # VAEDecode. Same HF repo / download-mode behavior as the text encoder.
      "qwen_image_vae.safetensors" = {
        url = "https://huggingface.co/Comfy-Org/Krea-2/resolve/main/vae/qwen_image_vae.safetensors";
        type = "vae";
        mode = "download";
        sha256 = "07rx08z24h9lpwjaj5z00y1v13qf82xhapy9x5z9crry47q801d7";
      };
      # Krea 2 LoRA pack [Krea 2] Beta V0.1 → bloomgirls-ultrarealism-krea2_4k.
      # CREATOR-GATED: anonymous downloads get 401 ("requires you to be logged
      # in") — the download-mode script uses the configured civitaiApiKeyPath
      # for these (curl -L never forwards the key to the CDN host).
      "bloomgirls-ultrarealism-krea2_4k.safetensors" = {
        urn = "urn:air:krea2:lora:civitai:2735553@3075850+2954934";
        sha256 = "13sr5iifd7vnfhi6mzd7zjl1hsdlqny07nbzr3aa5dbn7aysxgyi";
      };
      # [Krea 2] "v2 -krea2" LoRA (model 2187487).
      "cutifier_krea2.safetensors" = {
        urn = "urn:air:krea2:lora:civitai:2187487@3107521+2987468";
        sha256 = "1r7ssg3nc2dy4yzrn5r9v1mbag2xc94l0g4869fm0npw6xvj71vi";
      };
      # "Krea2 v3.0" LoRA (model 2688234) → realism_engine_krea2_v3.1.
      "realism_engine_krea2_v3.1.safetensors" = {
        urn = "urn:air:krea2:lora:civitai:2688234@3109006+2988982";
        sha256 = "19albd5n6f41j74zg84ix0c7b34czaz853jn2sk92bjs8hljcwd6";
      };
      # "Krea 2 v1.4" LoRA (model 1972981) → snofs_krea_v1_4.
      "snofs_krea_v1_4.safetensors" = {
        urn = "urn:air:krea2:lora:civitai:1972981@3290120+3174557";
        sha256 = "0cl958w3vnaby3fib9ajw8qp8apyfkqi63wkrwa3y043vvnqhy3n";
      };
      # Model 2738703 is a WORKFLOW, not a model (type "Workflows", file =
      # krea2SFWNSFWUncensoredImageTo_v10.json). The URN says <type> "unknown",
      # so the folder is set explicitly to "workflows" → lands in
      # user/default/workflows/ (where ComfyUI reads workflow JSONs).
      "krea2SFWNSFWUncensoredImageTo_v10.json" = {
        urn = "urn:air:krea2:unknown:civitai:2738703@3079753+2962861";
        type = "workflows";
        sha256 = "1ys4pfhj13s3h7rnr3c7vpgl7xd47kkfqbv3b4lmxggbx2jgik99";
      };
    };
  };

  # ── Manga Reader (sync library to config repo) ───────────────────────────
  my.services.suwayomi = {
    enable = true;
    autoBindTailscaleIp = true;
    settings.server = {
      # backupInterval is a FREEFORM HOCON field (options.nix freeformType) — cannot carry a
      # module default, so it stays explicit here (recon F11)
      backupInterval = 0;
    };
    openFirewall = true;
    # F11: extensionRepos, sync.export.{enable,autoPush,repoPath,secretPath}, sync.import.enable
    # now module defaults (suwayomi/sync-options.nix) — invariant core duplicated desktop/server removed
    sync.export.interval = "daily"; # F11: divergent — desktop hourly vs server daily (recon F11)
  };

  # Caddy upstream must point to the Tailscale IP when autoBindTailscaleIp is on
  my.services.proxy.upstreams.suwayomi.host = "100.78.102.28";

  # ── Minecraft Server ────────────────────────────────────────────────────
  # Server definitions live in modules/nixos/minecraft-server/servers/ — each
  # file defines one complete server. They are disabled by default; enable the
  # ones you want here or from a profile (e.g. my.profiles.gaming.minecraftServers).
  # DISABLED 2026-09-01 (ComfyUI priority): the Prominence II JVM (~5.5G RSS,
  # CPU-heavy) is paused to free CPU/RAM/IO for image gen. Flip `enable` back
  # to true to resume; all server definitions below are kept intact.
  my.services.minecraftServer = {
    enable = false;
    eula = true; # Mojang EULA — required
    dataDir = "/mnt/data/minecraft";
    packDir = "/mnt/data/minecraft/packs"; # scp modpack zips here

    # Web console: https://server.tail685690.ts.net/mc/prominence/
    web = {
      enable = true;
      portBase = 7781; # avoid colliding with my.services.ttyd (7681)
      proxyUpstream = true;
    };
    api.enable = true; # dashboard management (status + start/stop/restart)

    # Prominence II Fabric pack is kept defined for when the module is
    # re-enabled. AllTheTech is disabled (kept for reference); flip the
    # booleans to switch servers.
    servers.prominence.enable = true;
    servers.allthetech.enable = false;
  };

  # ── Ollama (LLM Serving) — disabled 2026-09-01 ─────────────────────────
  # Competed with ComfyUI for the GPU (12GB RTX 3060). dataDir/model kept so
  # re-enabling is a one-flag flip back to true — pair with
  # my.profiles.ai.enable = true above.
  my.services.ollama = {
    enable = false;
    dataDir = "/mnt/data/ollama";
    gpu.enable = true;
    models = {
      "hf.co/Lewdiculous/DS-R1-Qwen3-8B-ArliAI-RpR-v4-Small-GGUF-IQ-Imatrix:Q4_K_M-imat" = {
        name = "ArliAI DS-R1-Qwen3-8B RpR v4";
        numCtx = 16000;
        temperature = 0.6;
        topP = 0.95;
        topK = 40;
        repeatPenalty = 1.1;
      };
    };
  };

  # ── RisuAI (LLM Roleplay Frontend) — dormant 2026-09-01 ────────────────
  # Disabled together with my.profiles.ai (Ollama paused for ComfyUI). Config
  # kept for re-enabling; values are inert while the profile is off.
  my.services.risuai = {
    dataDir = "/mnt/data/risuai";
    ollama.enable = true;
    # H12: attach risuai to ollama-net (so it resolves ollama:11434) via the module's
    # network.name option — replaces the hand-rolled docker-risuai-ollama-net unit removed below.
    network.name = "ollama-net";
    # Default user settings enforced into the RisuAI save DB on container start:
    # parse thinking out of replies (was 'auto', which leaked <think> blocks) and
    # disable strict JSON schema so prose stays conversational.
    settings = {
      ollamaThinkingMode = "on";
      strictJsonSchema = false;
    };
  };

  # ── Neko (Remote Browser) — server-side Firefox session ─────────────────
  # Re-enabled for the Civitai dashboard entry: browser session/profile lives
  # on this US box (open from any machine at /neko/), auto-login to Civitai
  # inside it, traffic egress via this server. natIp default = this box's
  # tailscale IP (tailscale0 is a trusted firewall interface).
  my.services.neko = {
    enable = true;
    adminPasswordFile = config.age.secrets."neko-admin-password".path;
    userPasswordFile = config.age.secrets."neko-user-password".path;
    # Persistent Firefox profile (named docker volume → survives container
    # restarts/updates). Without it the Civitai session/login would be lost on
    # every container restart.
    extraVolumes = [ "neko-profile:/home/neko/.mozilla" ];
  };

  # ── Squid Forward Proxy (Browser Egress) ────────────────────────────────
  my.services.squidProxy.enable = true;

  # H12: hand-rolled docker-risuai-ollama-net oneshot removed — the risuai module's
  # network.name option (set above to "ollama-net") now attaches the container at creation,
  # and the module + ollama both inspect-guard network creation, so no duplicate unit is needed.

  # ── SSH Access ──────────────────────────────────────────────────────────
  # F12: extra key only — me.sshKey is inherited from common.nix mkDefault.
  # Must stay lib.mkDefault: a plain assignment would override common's
  # mkDefault and LOSE me.sshKey; same-priority mkDefaults merge via
  # types.listOf concatenation → [ me.sshKey "desktop-key" ].
  my.services.ssh.authorizedKeys = lib.mkDefault [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGEp55lp8743MYUsvmZ4XXnhvJ7c5GQDQzIg9GQzWPbg sean.cairnsst@gmail.com" ]; # desktop

  # ── Music Playlists (moved from desktop 2026-08-21) ─────────────────────
  # Hash-pinned music playlists (modules/nixos/music/playlists/) installed
  # into the media drive — songs declared in git, byte-pinned via
  # checksums.json. `example` is a `direct` source (Nix FOD); `funky` is a
  # yt-dlp source from a Spotify-CSV sync (runtime downloader outside the
  # build sandbox — see config.nix).
  my.services.music.enable = true;
  my.services.music.playlists.example.enable = true;
  my.services.music.playlists.funky.enable = true;

  # ── Unfree Software (allowUnfree set globally in flake.nix) ────────────
  nixpkgs.config = {
    # allowUnfree removed — globally set in flake.nix perSystem (M4d)
    cuda.acceptLicense = true;
  };

}
