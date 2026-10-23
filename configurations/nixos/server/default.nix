{ flake, lib, config, pkgs, ... }:
let
  # Served model id — the llama.cpp router's INI section name and the string
  # SillyTavern sends as `model`. Both modules must agree; neither reads the
  # other, so it is bound once here.
  lumimaidModel = "lumimaid-8b";

  # Llama-3-8B's trained context (LimaRP data was 8k). The GGUF page pairs a
  # smaller Q4_K_M with 12288 on an 8 GB card; this host's 12 GB RTX 3060 runs
  # Q6_K at the native 8192 with room for the KV cache.
  lumimaidContext = 8192;
in
{
  imports = [
    ./configuration.nix
    ./hardware-configuration.nix
    ./disk-config.nix
    flake.inputs.self.nixosModules.common
    # llama.cpp inference backend for SillyTavern (services.llama-cpp-nixos).
    flake.inputs.sillytavern.nixosModules.llama-cpp
    # Local speech backend (services.breeze-tts-nixos). Independent lifetime;
    # the SillyTavern module notices it and points the TTS provider at it.
    flake.inputs.sillytavern.nixosModules.breeze-tts
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
    # NVIDIA headless + CUDA — ENABLED 2026-10-21 for the llama.cpp backend
    # (services.llama-cpp-nixos with pkgs.llama-cpp-cuda) in SillyTavern.
    # The driver/CUDA closure is the biggest build-time and disk consumer on
    # this box; ComfyUI stays off (`my.services.comfyui.enable = false`) so the
    # GPU has one workload.
    gpu.nvidia-headless.enable = true;
    location.enable = true;
  };

  # ── Hardening CPU quotas — only list units that actually exist ─────────
  # The hardened default cpuQuota references docker-ollama/podman-ollama/
  # jellyfin; hardening mapAttrs' CREATES a unit definition for every name in
  # the list, so with the AI stack paused it shipped a docker-ollama unit with
  # no ExecStart — systemd refused it and `nix run .#activate` exited 4
  # ("Service has no ExecStart="). Empty for the same reason now that
  # comfy-ui is disabled too — every listed name must have a live ExecStart.
  my.system.hardening.cpuQuota = { };

  # ── Remote availability: reboot rather than stay unreachable ────────────
  # 2026-10-19: a raw `nix flake check` reached 10.5G anon-RSS and triggered a
  # global OOM; the box was unreachable until it recovered. The hardening
  # module now caps user.slice/nix-daemon and runs earlyoom (see
  # modules/nixos/hardening/README.md). These two are the last resort: if PID 1
  # is starved for 60s the hardware watchdog resets the machine, and the PiKVM
  # can send Alt+SysRq+F/B (kernel.sysrq=1; the default 16 only allows sync).
  my.system.hardening = {
    watchdog.runtimeSec = "60s";
    magicSysRq.enable = true;
  };

  # ── Jupyter — DISABLED 2026-10-16 ──────────────────────────────────────
  # common.nix enables the development profile on every host (mkDefault true),
  # and development.nix turns on Jupyter from it. On this headless server the
  # JupyterLab closure (jupyter-server/lab/lsp/notebook) is heavy AND its
  # upstream jupyter-server test suite is flaky — test_disconnect_resolves_
  # orphaned_kernel_info_future fails with an asyncio TimeoutError, which fails
  # the whole toplevel build. Override the universal default here; re-enable
  # with `enable = true` if you want notebook projects on the server.
  my.services.jupyter.enable = false;

  # ── VS Code Server ──────────────────────────────────────────────────────
  # Enables Remote-SSH on NixOS (patches dynamically linked Node binaries).
  # Disabled to trim build time/closure — flip back to true to use Remote-SSH.
  my.programs.vscode.server.enable = false;

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
  # Prism Launcher (Minecraft client) — DISABLED to trim build time/closure.
  # Pulls a large Qt/Java app; only needed for the remote-GUI Minecraft session
  # below. Re-enable with `enable = true` (+ the remoteGui block) to restore.
  my.homeManager.extraConfig.my.programs.minecraft = {
    enable = false;
    dataDir = "/mnt/data/prismlauncher";
  };

  # ── Remote GUI (Prism Launcher on a virtual display) ────────────────────
  # DISABLED to trim build time/closure — Prism Launcher/Openbox/Xvfb is a
  # heavy GUI stack only needed for the remote Minecraft session. Re-enable to
  # restore the browser VNC console at vncviewer server:5900.
  my.services.remoteGui = {
    enable = false;
    windowManager = pkgs.openbox; # decorations + focus for the launcher window
    apps.prismlauncher = {
      command = "${pkgs.prismlauncher}/bin/prismlauncher --dir /mnt/data/prismlauncher";
      user = "seanc";
    };
  };
  # Terminal opencode must not run while the browser (web) session is live —
  # both share ~/.config/opencode and the ensemble DB. Gate both directions.
  my.homeManager.extraConfig.my.programs.opencode.sessionGate.enable = true;

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
  systemd.tmpfiles.rules = [
    "d /mnt/data/nix-build 0755 root root -"
    # GGUF weights for services.llama-cpp-nixos (operator-managed, on disk).
    "d /mnt/data/llama 0755 root root -"
  ];

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

  # ── ComfyUI (AI Image Generation) — DISABLED 2026-10-16 ────────────────
  # Was the primary GPU workload (RTX 3060 12GB). Disabled to cut rebuild
  # time and reclaim disk: the ComfyUI python/torch closure plus its 22
  # curated custom-node packs is the largest build in this config. Re-enable
  # with `enable = true` AND `gpu.nvidia-headless.enable = true` above.
  my.services.comfyui = {
    # enable is explicit now that profiles/system/ai.nix no longer supplies it
    enable = false;
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

  # ── llama.cpp (LLM inference backend, CUDA) ────────────────────────────
  # Upstream's separate NixOS module (services.llama-cpp-nixos, NOT nixpkgs'
  # services.llama-cpp). Router mode: one port serves every declared model and
  # the section name is the `model` id the API routes on.
  services.llama-cpp-nixos = {
    enable = true;
    # nixpkgs builds the CUDA kernels for nine architectures
    # (75;80;86;89;90;100;103;120a;121a), which is ~9x the nvcc work and none
    # of it runs here: this box has exactly one GPU, an RTX 3060 (sm_86).
    package = pkgs.llama-cpp-cuda.overrideAttrs (oa: {
      cmakeFlags = (oa.cmakeFlags or [ ]) ++ [ "-DCMAKE_CUDA_ARCHITECTURES=86" ];
    });
    host = "127.0.0.1";
    port = 9931;

    models.${lumimaidModel} = {
      # Weights are operator-managed on the data disk (6.6 GB would otherwise
      # sit in the /nix store on a 116 GB root that is ~87% full). One-time
      # fetch:
      #   curl -L -o /mnt/data/llama/lumimaid-8b-Q6_K-imat.gguf \
      #     https://huggingface.co/Lewdiculous/Llama-3-Lumimaid-8B-v0.1-OAS-GGUF-IQ-Imatrix/resolve/main/v2-Llama-3-Lumimaid-8B-v0.1-OAS-Q6_K-imat.gguf
      # Quant choice from the GGUF card: Q4_K_M-imat is the 8 GB-VRAM pick for
      # up to 12288 context; with 12 GB this Q6_K (6.6 GB) fits at 8192 with
      # the KV cache (~1 GB) and compute buffers.
      weights.path = "/mnt/data/llama/lumimaid-8b-Q6_K-imat.gguf";
      ctxSize = lumimaidContext;
      primary = true;
      args = {
        ngl = "all"; # 32/32 layers on the RTX 3060
        "flash-attn" = "on";
        # The card specifies Llama 3 prompting, and the GGUF's metadata does
        # NOT agree: this conversion carries a ChatML template. Worse,
        # `chat-template = "llama3"` does not resolve in llama.cpp 0.4.1 —
        # the NAME is stored verbatim as a 6-character template, so every
        # request's prompt became the literal string `llama3` (4 tokens) and
        # the model free-associated ("I am a llama, but I am not a typical
        # llama…" to "What is 2+2?"). `chat-template-file` renders the real
        # jinja: prompt 4 -> 27 tokens and the answer is "4".
        "chat-template-file" = "${./llama3-instruct.jinja}";
      };
    };
  };

  # The module's launcher is a writeShellApplication whose only job is to
  # export LLAMA_ARG_API_KEY from a systemd credential. In nixpkgs 20b1ddd it
  # builds: upstream split the assignment from the `export` (shellcheck could
  # not model `set -a`, so SC2034 failed the build). The launcher now guards
  # the credential read, so a keyless loopback instance works without an
  # override. Host/port/models-preset come from the unit's environment
  # (LLAMA_ARG_*), not the command line.

  # ── SillyTavern (LLM Roleplay Frontend) ────────────────────────────────
  # Options live under `services.sillytavern-nixos.*` — the upstream
  # github:Cairnstew/SillyTavern flake module, wrapped by
  # modules/nixos/sillytavern. The namespace is NOT `services.sillytavern`:
  # that one belongs to nixpkgs' own module, and the two cannot be enabled at
  # the same time (they share the unit, the account and the state directory).
  # Served at https://server.tail685690.ts.net:8444/ (tailnet only, see the
  # tailscale-serve unit below). NOT under the Caddy /sillytavern/ subpath:
  # with accounts enabled SillyTavern 302s to a root-relative /login and its
  # login JS sets pathname = "/" on success, so a path-prefixed install drops
  # the user on the dashboard. Root-of-its-own-port has no such problem.
  services.sillytavern-nixos = {
    enable = true;

    # The package's npm ci runs in the fixed-output node_modules build, where
    # /etc/ssl is absent and nixpkgs' node has no system bundle to fall back
    # to. Upstream now defaults `caCertFile` to nss-cacert's `ca-bundle.crt`
    # (not the non-existent `ca-certificates.crt` the docs used to name), so
    # the stock package builds without an override.

    # Loopback-only (the default); tailscale serve terminates tailnet TLS and
    # forwards to 127.0.0.1:8000.
    config.port = 8000;

    # Access control is SillyTavern's own account system — the module refuses
    # to enable the service with no accounts configured (default-user is
    # created with an EMPTY password, which is unloginable, and a declared
    # user without a passwordFile would be PASSWORDLESS, not disabled).
    # Accounts are the real gate, so the IP whitelist (which would otherwise
    # see the tailscale-serve peer as 127.0.0.1 anyway) stays off.
    config.enableUserAccounts = true;
    config.whitelistMode = false;
    # Host-header check: tailscale serve forwards the public name, and without
    # this the server logs "Request from untrusted host" on every request.
    # `host-validation-middleware` strips the port before matching.
    config.hostWhitelist = {
      enabled = true;
      # `localhost` is only reachable from the box itself (the server binds
      # 127.0.0.1), and without it the dashboard's local card — href
      # http://localhost:8000/ — is answered with 403 "untrusted host".
      hosts = [ "server.tail685690.ts.net" "localhost" ];
    };

    # Point the account's Chat Completion at the local llama.cpp router and
    # select the seeded preset, so a fresh login is already on the GGUF rather
    # than the OpenAI default.
    settings.common.oai_settings = {
      chat_completion_source = "custom";
      custom_url = "http://127.0.0.1:9931/v1";
      custom_model = lumimaidModel;
      preset_settings_openai = lumimaidModel;
      openai_max_context = lumimaidContext;
      openai_max_tokens = 512;
      stream_openai = true;
      bind_preset_to_connection = true;
    };

    # Chat-completion wiring for the locally served GGUF. `contextSize` must
    # match services.llama-cpp-nixos.models.<id>.ctxSize (the modules do not
    # read each other); it becomes `openai_max_context` in the generated
    # preset. Sampling is a Llama-3 RP baseline — the GGUF card points at
    # Virt's SillyTavern presets for the author's tuned values, which are
    # imported in the UI if wanted.
    modelLayers = {
      enable = true;
      catalog.${lumimaidModel} = {
        contextSize = lumimaidContext;
        connection = {
          url = "http://127.0.0.1:9931/v1";
          model = lumimaidModel;
        };
        presets.openai = {
          temp_openai = 0.9;
          top_p_openai = 0.95;
          top_k_openai = 40;
          min_p_openai = 0.05;
          top_a_openai = 0;
          freq_pen_openai = 0;
          pres_pen_openai = 0;
          repetition_penalty_openai = 1.05;
          openai_max_tokens = 512;
        };
      };
    };
    users.seanc = {
      name = "Sean";
      admin = true;
      passwordFile = config.age.secrets."sillytavern-password".path;
    };

    # Extensions/plugins are pinned store paths; the UI's update button would
    # fail against a read-only path. (Also forced off upstream when any are
    # declared; spelled out for the record.)
    config.extensions.autoUpdate = false;

    # No `systemdOverrides` any more. Both raw-unit escapes were upstream
    # defects, fixed in 6cee6f7: the hardening list no longer sets
    # `MemoryDenyWriteExecute` (V8 JIT needs W+X pages; node died at isolate
    # init with SIGTRAP), and `ExecStart` is one `escapeShellArgs` string
    # instead of a list that rendered as three `ExecStart=` lines.
  };

  # SillyTavern is served at the root of its own tailnet HTTPS port, so the
  # wrapper's Caddy /sillytavern/ upstream (and its root-relative asset
  # handles) would only advertise a broken link on the dashboard.
  my.services.proxy.upstreams.sillytavern.enable = false;

  # …so it, the TTS UI and opencode web are listed as direct cards instead. All
  # three live on their own tailnet port; servePort makes the dashboard link to
  # https://<current-host>:<port>/ unless it is being viewed from localhost.
  my.services.proxy.dashboard.links = [
    {
      label = "SillyTavern";
      description = "Roleplay frontend — local llama.cpp model (${lumimaidModel})";
      href = "http://localhost:8000/";
      servePort = 8444;
    }
    {
      label = "Breeze TTS";
      description = "Local speech: voice design/cloning and /v1/audio/speech";
      href = "http://localhost:8445/";
      servePort = 8445;
    }
    {
      label = "opencode web";
      description = "opencode web UI (nix-config instance)";
      href = "http://localhost:4200/";
      servePort = 8443;
    }
  ];

  # ── Breeze TTS 2 (local speech, Vulkan) ────────────────────────────────
  # OpenAI-compatible `/v1/audio/speech` on loopback, plus the bundled web UI
  # at `/`. Separate unit from the LLM and the frontend: its own lifetime, its
  # own GPU footprint.
  services.breeze-tts-nixos = {
    enable = true;

    # The catalogue's small safe quant. Measured by upstream on this exact
    # hardware class (RTX 3060 12 GiB + a Q4/Q6 8B resident): the file is
    # 2.4 GiB and it claims ~3.0 GiB of VRAM while serving, leaving ~1.7 GiB
    # free. q8_0 needs ~1 GiB more and only fits if the LLM stays under ~7 GiB.
    model = "q4_k";
    # Fetch into /var/lib/breeze-tts/models on start and verify the pinned
    # sha256 every time. The alternative is a one-time curl by hand; this is
    # self-healing (a mismatched file is discarded and re-fetched) and keeps
    # the weights out of the store, where 2.4 GiB would stay pinned.
    downloadModel = true;

    # Serve the browser UI. It has NO authentication and NO rate limiting, so
    # it stays on loopback and is published only to the tailnet (below).
    webui = true;

    # The UI's WebSocket URL is `wss://<page host>:<ws_port>` with `ws_port`
    # reported by the server itself (webui/app.js), so the two ports are the
    # tailnet-facing ones: tailscale serve maps 8445 -> UI and 8446 -> WS, and
    # the reported ws_port is 8446, which is exactly what the browser (loaded
    # from :8445) will dial. 8443/8444 are opencode-web/SillyTavern.
    port = 8445;
    wsPort = 8446;

    # Every voice is a pre-encoded blob, so it is a build artifact rather than a
    # service action: the unit installs each file before the server scans the
    # directory, validates the BRZV magic, and records it in a .nix-managed
    # manifest so removing an entry deletes the file. The SillyTavern module
    # unions declared names into available_voices, so the dropdown cannot drift
    # from the backend.
    #
    # `narrator` started life as a runtime voice (design -> POST /v1/voices,
    # which wrote /var/lib/breeze-tts/voices/narrator.breeze); its blob is
    # committed next to this file.
    #
    # The Overwatch voices come from the overwatch-voice-lines flake: one
    # `<character>-voice` package per packs/<character>/ directory, each a
    # single `<Name>.breeze` named from that pack's voice.json. The attribute
    # name is the id SillyTavern sees, so it must match the filename stem, and
    # the package name is that stem lowercased (Mercy -> mercy-voice). Upstream
    # discovers packs from the directory, so a new character needs an input
    # bump plus one name in this list — no flake.nix edit on either side.
    voices =
      lib.genAttrs
        [ "Ana" "Cassidy" "Mercy" "Moira" "Reaper" "Sombra" "Tracer" ]
        (name: {
          source =
            flake.inputs.overwatch-voice-lines.packages.${pkgs.stdenv.hostPlatform.system}."${lib.toLower name}-voice";
        })
      // {
        narrator.source = ./voices/narrator.breeze;

        # Widowmaker is spelled out rather than covered by the list above
        # because it also carries per-voice generation defaults.
        Widowmaker = {
          source =
            flake.inputs.overwatch-voice-lines.packages.${pkgs.stdenv.hostPlatform.system}.widowmaker-voice;

          # Written to `Widowmaker.json` next to the blob and applied when a
          # request selects the voice without setting the field itself
          # (request > sidecar > GGUF default). For a cloned voice the reference
          # owns timbre, so `instruction` steers delivery only.
          #
          # cfgScale is the one model knob worth moving: 1.25 follows the
          # direction more closely than the default 1.0 without the
          # real-time-factor cost of 1.5+. The sampling and splitting fields
          # stay at the model defaults — they alter prosody/artifacts far more
          # than they improve a cloned line.
          generation = {
            instruction = "Cold and aristocratic, clipped, a touch quick; sharp-edged, dry and contemptuous.";
            cfgScale = 1.25;
          };
        };
      };

    # The static budget: model 3072 + headroom 768 + the LLM's reserve 7000
    # = 10840 <= 12288, so `nixos-rebuild` refuses a config that cannot fit.
    # The start-time probe still reads the driver's real free VRAM (3840 MiB
    # required) — it currently sees ~4.7 GiB free with lumimaid-8b resident.
    gpu.totalVramMiB = 12288;
    gpu.reserveForOtherMiB = 7000;
  };

  # Speak assistant replies in the UI. The endpoint itself is wired
  # automatically (the SillyTavern module reads the Breeze port), so this only
  # flips `extension_settings.tts.enabled`.
  services.sillytavern-nixos.tts.enable = true;
  # No `tts.voices` list: the declared voice above is unioned into
  # `available_voices` by the module (managedTtsVoices), so the backend's
  # voices directory is the single source of truth for ids.
  #
  # `available_voices` must still not end up empty: the TTS extension's Default
  # Voice row only offers `disabled` when the provider lists no voices. That is
  # why the declared voice exists at all, rather than relying on reference-free
  # design.
  services.sillytavern-nixos.settingsExtra.extensionSettings.tts."OpenAI Compatible".voiceMap =
    "[Default Voice]:narrator";

  # Tailnet HTTPS for the TTS UI and its WebSocket. Both are HTTP backends on
  # loopback; tailscale terminates TLS and forwards, same pattern as the two
  # services above. Separate ports because the UI dials host:ws_port directly.
  systemd.services.breeze-tts-tailnet-serve = {
    description = "tailscale serve: Breeze TTS web UI (:8445) + WebSocket (:8446)";
    wantedBy = [ "multi-user.target" ];
    wants = [ "tailscaled.service" ];
    after = [ "tailscaled.service" "breeze-tts-nixos.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "breeze-tts-tailnet-serve" ''
        set -euo pipefail
        ts=${lib.getExe pkgs.tailscale}
        $ts serve --bg --https 8445 http://127.0.0.1:8445
        $ts serve --bg --https 8446 http://127.0.0.1:8446
      '';
      ExecStop = pkgs.writeShellScript "breeze-tts-tailnet-unserve" ''
        set -euo pipefail
        ts=${lib.getExe pkgs.tailscale}
        $ts serve --https 8445 off || true
        $ts serve --https 8446 off || true
      '';
    };
  };

  # Tailnet HTTPS endpoint for SillyTavern (same pattern as opencode-web's
  # per-instance tailscale serve): terminate TLS on the tailnet and forward to
  # the loopback listener. 8443 is opencode-web; 8444 is free.
  systemd.services.sillytavern-tailnet-serve = {
    description = "tailscale serve: SillyTavern on :8444";
    wantedBy = [ "multi-user.target" ];
    wants = [ "tailscaled.service" ];
    after = [ "tailscaled.service" "sillytavern.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.tailscale}/bin/tailscale serve --bg --https 8444 http://127.0.0.1:8000";
      ExecStop = "${pkgs.tailscale}/bin/tailscale serve --https 8444 off";
    };
  };

  # ── Neko (Remote Browser) — DISABLED to trim build time/closure ──────────
  # Was a server-side Firefox session for the Civitai dashboard. Pulls a full
  # Firefox container; re-enable with `enable = true` to restore.
  my.services.neko = {
    enable = false;
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

  # ── Music Playlists — DISABLED to trim build time/closure ──────────────
  # (moved from desktop 2026-08-21). Hash-pinned music playlists
  # (modules/nixos/music/playlists/) installed into the media drive — songs
  # declared in git, byte-pinned via checksums.json. `example` is a `direct`
  # source (Nix FOD); `funky` is a yt-dlp source from a Spotify-CSV sync
  # (runtime downloader outside the build sandbox). Re-enable with
  # `enable = true` (+ the two playlists) to restore.
  my.services.music.enable = false;

  # ── Unfree Software (allowUnfree set globally in flake.nix) ────────────
  nixpkgs.config = {
    # allowUnfree removed — globally set in flake.nix perSystem (M4d)
    # cuda.acceptLicense removed 2026-10-16 — NVIDIA/CUDA disabled above, so
    # accepting the CUDA licence would only drag the toolkit closure back in.
  };

}
