{ flake, lib, config, pkgs, ... }:
let
  # Served model id — the Ollama model name (and previously the llama.cpp
  # router's INI section name) and the string SillyTavern sends as `model`.
  # Both modules must agree; neither reads the other, so it is bound once here.
  lumimaidModel = "lumimaid-8b";

  # Llama-3-8B's trained context (LimaRP data was 8k). The GGUF page pairs a
  # smaller Q4_K_M with 12288 on an 8 GB card; this host's 12 GB RTX 3060 runs
  # Q6_K at the native 8192 with room for the KV cache.
  lumimaidContext = 8192;

  # Default model selected in SillyTavern. One of the HuggingFace-pulled
  # Personal Favorites: use the Ollama safeName (slashes normalised) that
  # `my.services.ollama.models` and `modelLayers.catalog` both name, not the
  # local `lumimaid-8b` alias. `defaultModelPreset` is the catalog key, which
  # is also the generated Chat Completion preset name.
  defaultModel = "hf.co-Lewdiculous-Lumimaid-v0.2-8B-GGUF-IQ-Imatrix-Q6_K-imat";
  defaultModelPreset = "lumimaid-v2-8b";

  # Canonical Ollama Go templates, used for every local model because GGUF
  # metadata templates cannot be trusted here: lumimaid-8b v0.1 stores the
  # bare name `llama3` (renders literally), while the newer quants carry full
  # llama.cpp jinja (`{% %}`), which is not valid Go-template syntax and fails
  # `ollama create` at parse time. Pinning these removes all metadata
  # dependence; ST's per-request sampling (temp/top_p/penalties) is unaffected.
  llama3OllamaTemplate = ''
    {{- if .System }}<|start_header_id|>system<|end_header_id|>

    {{ .System }}<|eot_id|>{{ end }}{{ if .Prompt }}<|start_header_id|>user<|end_header_id|>

    {{ .Prompt }}<|eot_id|>{{ end }}<|start_header_id|>assistant<|end_header_id|>

    {{ .Response }}<|eot_id|>
  '';
  # NOTE 2026-10-31: an earlier revision put `{{ .Response }}</s>` inside each
  # branch; Ollama's template parser panicked at render time (`parse.Node is
  # nil, not *parse.ListNode*, HTTP 500 on every generate) for all four
  # Mistral-family models. Single `{{ .Response }}` outside the conditional
  # matches Ollama's own mistral template shape and renders correctly.
  mistralOllamaTemplate = ''
    {{- if .System }}<s>[INST] {{ .System }} {{ .Prompt }} [/INST]{{ else }}<s>[INST] {{ .Prompt }} [/INST]{{ end }} {{ .Response }}</s>
  '';
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
    # ai.enable disabled 2026-09-01 (ComfyUI priority): the AI frontends
    # (RisuAI, Open WebUI, Letta) stay paused. Ollama itself was re-enabled
    # 2026-10-28 (see `my.services.ollama` below), but enabling the ai profile
    # would also turn those frontends back on.
    ai.enable = false;
    # NVIDIA headless + CUDA — ENABLED 2026-10-21 for the llama.cpp backend
    # (services.llama-cpp-nixos with pkgs.llama-cpp-cuda) in SillyTavern.
    # Left enabled after the 2026-10-27 stack shutdown: it is what gives the
    # Ollama container its GPU (--device=nvidia.com/gpu=all via CDI), and
    # ComfyUI would need it too.
    gpu.nvidia-headless.enable = true;
    location.enable = true;
  };

  # ── Hardening CPU quotas — only list units that actually exist ─────────
  # The hardened default cpuQuota references docker-ollama/podman-ollama/
  # jellyfin; hardening mapAttrs' CREATES a unit definition for every name in
  # the list, so with the AI stack paused it shipped a docker-ollama unit with
  # no ExecStart — systemd refused it and `nix run .#activate` exited 4
  # ("Service has no ExecStart="). Empty here; entries are added below only
  # under the `lib.mkIf` of the service that creates the unit (comfy-ui,
  # docker-ollama), so a disabled service cannot ship a unit with no ExecStart.
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
  # Kept off to trim build time/closure — flip to true here to use Remote-SSH.
  # No `enable = false;` line: the option is lib.mkEnableOption (default false),
  # so setting false was dead and has been removed.

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

  # ── ComfyUI (AI Image Generation) — DISABLED 2026-10-26 ────────────────
  # Turned off so the SillyTavern stack (llama.cpp + Breeze TTS) owns the
  # RTX 3060 again. It was off from 2026-10-16 to cut rebuild time and reclaim
  # disk (the torch closure + 22 node packs is the largest build in this
  # config), re-enabled 2026-10-24, and is off again now. Flip `enable` back
  # to true (with `gpu.nvidia-headless.enable = true` above) to restore; the
  # presets/models below are intact. The resource guards further down are
  # gated on the same flag so disabling cannot leave a unit with no ExecStart.
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
      # Bjornulf LITE — text/list + looping helpers used by the krea2-grid
      # workflow (LoopInteger/LoopAllLines drive ComfyUI's native list
      # expansion so one Queue click renders every prompt combination, and
      # CombineTexts composes the prompt in one node).
      "Bjornulf_custom_nodes_LITE"
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
      # "hot shot" (krea selfie aesthetic) — **Krea 2** LoRA (model 2999042,
      # version 3401718, file 3314841; 218 MiB, nsfw). No trained trigger
      # words. Base model matches the installed Krea 2 UNet, so unlike a Flux
      # LoRA it applies to krea2-simple; add it as a row in the rgthree stack
      # ("➕ Add Lora"). Anonymous civitai downloads 307 to a login page, so
      # prepare-dirs sends civitaiApiKeyPath; download mode (data disk).
      "hotShotKreaSelfie_v1.safetensors" = {
        urn = "urn:air:krea2:lora:civitai:2999042@3401718+3314841";
        sha256 = "0m2hgn27ci43i94kf9kf43w8gw33v5hj1kk8rrcfd7gbgcfmmwjd";
      };
      # "Selfie POV (Amateurstyle)" — Krea 2 LoRA (model 2226100, version
      # 3390306, file 3279730; ~112 MiB, nsfw). Phone-shot selfie/POV
      # aesthetic with no required trigger words; base model is Krea 2, so
      # it stacks onto krea2-simple. Authenticated civitai download (same
      # civitaiApiKeyPath handling as hot shot); download mode on the data disk.
      "Krea2_Selfie_POV_v1.safetensors" = {
        urn = "urn:air:krea2:lora:civitai:2226100@3390306+3279730";
        sha256 = "0q20bhf7rcs05z7h4q9y12ghbnyj1n8s0pphkb2h0fl2i2rlwsra";
      };
      # "Realistic Snapshot" — **Krea 2** v1.0 LoRA (model 2268008, version
      # 3371723, file 3260432; 1.49 GB, nsfw). Smartphone-snapshot realism;
      # the safetensors metadata carries `ss_base_model_version: krea2`
      # (ai-toolkit, 6000 steps), so it stacks onto krea2-simple. Recommended
      # strength 1.5 (1.0 does little; up to 2.0 stays stable). NOTE: this
      # model's *other* version (3417962, "MOSS-Image v1.0") is trained for
      # MOSS Image — a separate OpenMOSS 5B DiT — and must not be used here.
      # The file name says "V2" because the author renamed it; version is v1.0.
      "RealisticSnapshotKrea2V2.safetensors" = {
        urn = "urn:air:krea2:lora:civitai:2268008@3371723+3260432";
        sha256 = "1g72a50pqkzshalrxxd4bynky2cin8884b9nzqjrz7jnvabl41mw";
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
      # BRIA RMBG-1.4 (~177 MiB) — subject matte for LayerStyle's
      # `LayerMask: RmBgUltra V2`, used by the krea2-inpaint workflow to mask
      # the person so only the subject is regenerated. LayerStyle does NOT
      # register an `rmbg` model folder, so `load_RMBG_model()` falls through
      # to models/rmbg/RMBG-1.4/model.pth — hence the nested `type` (the module
      # interpolates it verbatim into the folder path). Licence:
      # bria-rmbg-1.4, non-commercial use only.
      "model.pth" = {
        url = "https://huggingface.co/briaai/RMBG-1.4/resolve/main/model.pth";
        type = "rmbg/RMBG-1.4";
        mode = "download";
        sha256 = "132ypyp3rj4489bzhjci2yvsj38rji6plibq7v4szpdi831icg49";
      };

      # ── Wan 2.2 TI2V-5B — image→video (workflow: wan22-i2v-5b.json) ──────
      # 5B hybrid TI2V: the only Wan 2.2 variant that fits this box. The 14B
      # MoE pair is 14.3 GB *per expert* in fp8 and needs two UNets resident.
      # It is the OFFICIAL fp16 repack (10.0 GB, UNETLoader weight_dtype
      # "default"), not a GGUF: the 5B GGUFs in circulation (QuantStack
      # `Wan2.2-TI2V-5B-Q6_K.gguf`, and unsloth's fp8 `.pt`) carry 5-D tensors,
      # and the `gguf` python package pinned for ComfyUI-GGUF still has
      # `GGML_MAX_DIMS = 4` — loading fails at UnetLoaderGGUF with
      # "Tensor dimensions count 5 exceeds GGML_MAX_DIMS (4)". Verified
      # 2026-10-25. Kijai's `Wan2_2-TI2V-5B_fp8_e4m3fn_scaled_KJ.safetensors`
      # (5.28 GB) is the smaller option if fp16 ever thrashes, but it targets
      # WanVideoWrapper, not core UNETLoader.
      "wan2.2_ti2v_5B_fp16.safetensors" = {
        url = "https://huggingface.co/Comfy-Org/Wan-2.2/resolve/main/split_files/diffusion_models/wan2.2_ti2v_5B_fp16.safetensors";
        type = "diffusion_models";
        mode = "download";
        sha256 = "07nazvy6k6h4s3w5rji5lpl6i6ws20cvha1qxnysv7mx709r0vs5";
      };
      # Wan 2.2 VAE (1.4 GB, high-compression 48-channel — NOT the Wan 2.1 VAE,
      # and NOT the qwen_image_vae Krea 2 uses). Required by both
      # Wan22ImageToVideoLatent and VAEDecode in the video workflow.
      "wan2.2_vae.safetensors" = {
        url = "https://huggingface.co/Comfy-Org/Wan-2.2/resolve/main/split_files/vae/wan2.2_vae.safetensors";
        type = "vae";
        mode = "download";
        sha256 = "0mnizrsjnvjbpklx70394xld2g9hmjs0wlz2va8rjw5r6syj20z4";
      };
      # umt5-xxl text encoder (fp8 scaled, 6.74 GB) — CLIPLoader(type="wan").
      # Shared with every Wan model; Krea 2's qwen3vl encoder cannot be used.
      "umt5_xxl_fp8_e4m3fn_scaled.safetensors" = {
        url = "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors";
        type = "text_encoders";
        mode = "download";
        sha256 = "0s2g418sdsk6d9gxlzb2dk79v079g80vlgyr4rmhc7qz34q5sdf3";
      };
    };
  };

  # ── ComfyUI resource guards ──────────────────────────────────────────────
  # ComfyUI is the largest RAM/GPU consumer on this box, and the 2026-10-19
  # global OOM left the host unreachable. Cap the unit so a runaway workflow
  # or node pack is killed instead of starving sshd; oomd/earlyoom remain the
  # system-wide backstop (modules/nixos/hardening/README.md).
  # Gated on the enable flag: a bare `systemd.services.comfy-ui` (or a
  # `cpuQuota.comfy-ui` entry, which the hardening module turns into a unit
  # definition) with the service off has no ExecStart and fails activation.
  systemd.services.comfy-ui = lib.mkIf config.my.services.comfyui.enable {
    unitConfig = {
      StartLimitBurst = 5;
      StartLimitIntervalSec = 300;
    };
    serviceConfig = {
      MemoryHigh = "9G";
      MemoryMax = "11G";
      MemorySwapMax = "2G";
      TasksMax = 1024;
      LimitNOFILE = 65536;
      OOMPolicy = "stop";
      TimeoutStopSec = "30s";
    };
  };
  my.system.hardening.cpuQuota.comfy-ui =
    lib.mkIf config.my.services.comfyui.enable "600%";
  # Same guard for the Ollama container: only define the quota when the unit
  # actually exists (the module's default map is emptied above).
  my.system.hardening.cpuQuota.docker-ollama =
    lib.mkIf config.my.services.ollama.enable "400%";

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

  # ── Project Zomboid dedicated server (Viewpoint) ────────────────────────
  # The world moved here from desktop's in-game Host on 2026-11-11. Its save,
  # viewpoint.ini, db/viewpoint.db and Zomboid/Lua were copied into
  # /mnt/data/project-zomboid/viewpoint/Zomboid BEFORE this block was enabled,
  # so the prep script merges into the existing ini and preserves
  # Seed/ResetID/ServerPlayerID instead of generating a new world.
  #
  # `public = false`: this host is behind T-Mobile CGNAT, so it cannot
  # advertise a reachable address. Players join the PPextendo ZeroTier network
  # (363c67c55ab5da47) and connect to 172.23.49.211:16261 directly.
  #
  # `steamLogin`: the token is cached once under HOME=/mnt/data/project-zomboid
  # (see GOTCHAS.md); some Workshop items answer Access Denied anonymously.
  services.project-zomboid-servers = {
    enable = true;
    updateOnStart = true;
    steamLogin = "cairnsgerry";
    servers.viewpoint = {
      enable = true;
      # The shared definition sets these plainly, so a per-host override needs
      # mkForce rather than a same-priority assignment.
      autoStart = lib.mkForce true;
      public = lib.mkForce false;
      clientHost.enable = lib.mkForce false;
    };
  };

  # The dedicated server's prep script runs as `project-zomboid` and reads the
  # join password to merge `Password=` into viewpoint.ini. The manifest's
  # 0400 seanc:users is correct for the desktop's Home Manager render, but the
  # service user cannot read it, so hand it over on this host.
  age.secrets.pz-join-password = {
    owner = lib.mkForce "root";
    group = lib.mkForce config.services.project-zomboid-servers.group;
    mode = lib.mkForce "0440";
  };

  # ── Ollama (LLM Serving) — ENABLED 2026-10-31 ──────────────────────────
  # Restored on request 2026-10-31 as the SOLE inference backend (the llama.cpp
  # router below is off): all seven Personal Favorites GGUFs serve through the
  # container's native multi-model handling (loads on demand, evicts LRU after
  # keep_alive) instead of the router's manual sleep-swap. The model store
  # (/mnt/data/ollama) is intact. Breeze TTS is disabled since 2026-11-03, so
  # its ~3 GB of VRAM is back in the pool; the 12Bs fit comfortably when swapped
  # in (~7.3 GB weights + ~1.5 GB f16 KV, less with the q8 cache below).
  my.services.ollama = {
    enable = true; # re-enabled 2026-10-31 (sole backend; replaces llama.cpp)
    dataDir = "/mnt/data/ollama";
    # Pin: Docker Hub `latest` is 0.40.14; a missing-image pull would silently upgrade.
    image = "ollama/ollama:0.21.2";
    gpu.enable = true;
    performance = {
      flashAttention = true;
      kvCacheType = "q8_0";
    };
    # Operator GGUFs must be visible INSIDE the container at the same path
    # the models below name (ggufPath is a container path): bind-mount the
    # weights dir read-only.
    extraVolumes = [ "/mnt/data/llama:/mnt/data/llama:ro" ];
    models = {
      "hf.co/Lewdiculous/DS-R1-Qwen3-8B-ArliAI-RpR-v4-Small-GGUF-IQ-Imatrix:Q4_K_M-imat" = {
        name = "ArliAI DS-R1-Qwen3-8B RpR v4 (reasoning)";
        numCtx = 16000; # card: 16K training sequence length
        # Card "Recommended Samplers": temp 1.0 (was 0.6), topK 40 unchanged.
        temperature = 1.0;
        topP = 1.0; # desktop-proven for this model (was 0.95)
        topK = 40;
        # repeatPenalty 1.0 (= disabled): the card explicitly warns RpR v4
        # degrades with repetition-penalty samplers (even XTC/DRY). Was 1.1;
        # 1.0 rather than unset, because Ollama's own default is 1.1 and an
        # unset Modelfile would silently keep penalising. repeatLastN stays:
        # it only widens the window penalties would apply to.
        repeatPenalty = 1.0;
        repeatLastN = 2048;
        # NO template override: verified live 2026-10-31 that Ollama renders
        # this Qwen3 model correctly without one (native <think> reasoning
        # blocks). A ChatML template here would be wrong for Qwen3's native
        # CJK token format — do not add one without a generate roundtrip.
      };
      # Lumimaid-8B v0.1 (previous router primary). Local file: the repo holds
      # BOTH v1 and v2 Q6_K quants, so an `hf.co/...:Q6_K-imat` pull tag is
      # ambiguous — ggufPath pins the verified v2 file deterministically.
      # Usable name in ST/opencode: `lumimaid-8b` (no registry prefix, so the
      # safeName equals the tag and existing ST wiring keeps working).
      "lumimaid-8b" = {
        name = "Lumimaid 8B v0.1 (local v2 Q6_K)";
        ggufPath = "/mnt/data/llama/lumimaid-8b-Q6_K-imat.gguf";
        numCtx = lumimaidContext;
        temperature = 0.9;
        topP = 0.95;
        topK = 40;
        repeatLastN = 2048; # echo-fix parity with the old router flag
        template = llama3OllamaTemplate; # metadata stores bare `llama3`
      };
      # The remaining six pull straight from HF (single file per quant —
      # verified unambiguous 2026-10-31). Usable ST names are the
      # slash-normalised safeNames (e.g. hf.co-Lewdiculous-...); see catalog.
      "hf.co/Lewdiculous/L3-8B-Stheno-v3.1-GGUF-IQ-Imatrix:Q6_K-imat" = {
        name = "Stheno 8B v3.1 (Sao10K RP)";
        numCtx = 8192;
        temperature = 0.9;
        topP = 0.95;
        topK = 40;
        repeatLastN = 2048;
        template = llama3OllamaTemplate; # metadata jinja is not Go syntax
      };
      "hf.co/Lewdiculous/Lumimaid-v0.2-8B-GGUF-IQ-Imatrix:Q6_K-imat" = {
        name = "Lumimaid v0.2 8B (Llama 3.1)";
        numCtx = 8192;
        temperature = 0.8; # card note: lower temperatures for v0.2
        topP = 0.95;
        topK = 40;
        repeatLastN = 2048;
        template = llama3OllamaTemplate;
      };
      "hf.co/Lewdiculous/Kunoichi-DPO-v2-7B-GGUF-Imatrix:Q6_K-imatrix" = {
        name = "Kunoichi DPO v2 7B";
        numCtx = 8192;
        temperature = 0.9;
        topP = 0.95;
        topK = 40;
        repeatLastN = 2048;
        template = mistralOllamaTemplate;
      };
      "hf.co/Lewdiculous/InfinityRP-v1-7B-GGUF-IQ-Imatrix:Q4_K_M-imat" = {
        name = "InfinityRP v1 7B (anti-hallucination)";
        numCtx = 8192; # card states 8192 supported (metadata claims 32768)
        temperature = 0.9;
        topP = 0.95;
        topK = 40;
        repeatLastN = 2048;
        template = mistralOllamaTemplate;
      };
      "hf.co/Lewdiculous/Captain-Eris_Violet-V0.420-12B-GGUF-ARM-Imatrix:Q4_K_M-imat" = {
        name = "Captain Eris Violet 12B (Mistral Nemo)";
        numCtx = 8192;
        temperature = 0.9;
        topP = 0.95;
        topK = 40;
        repeatLastN = 2048;
        template = mistralOllamaTemplate;
      };
      "hf.co/Lewdiculous/Lumimaid-v0.2-12B-GGUF-IQ-Imatrix:Q4_K_M-imat" = {
        name = "Lumimaid v0.2 12B (Mistral Nemo)";
        numCtx = 8192;
        temperature = 0.9;
        topP = 0.95;
        topK = 40;
        repeatLastN = 2048;
        template = mistralOllamaTemplate;
      };
    };
  };

  # ── RisuAI (LLM Roleplay Frontend) — dormant 2026-09-01 ────────────────
  # Still off because my.profiles.ai stays off (Ollama itself is back up).
  # Config kept for re-enabling; values are inert while the profile is off.
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
    # Disabled 2026-10-31: serving moved to Ollama (native multi-model LRU),
    # which owns the RTX 3060 now. The model declarations below are INERT
    # while off (proven shape — ran like this Oct 24-28) and stay as the fast
    # rollback path; weights remain on /mnt/data/llama.
    enable = false;
    # nixpkgs builds the CUDA kernels for nine architectures
    # (75;80;86;89;90;100;103;120a;121a), which is ~9x the nvcc work and none
    # of it runs here: this box has exactly one GPU, an RTX 3060 (sm_86).
    package = pkgs.llama-cpp-cuda.overrideAttrs (oa: {
      cmakeFlags = (oa.cmakeFlags or [ ]) ++ [ "-DCMAKE_CUDA_ARCHITECTURES=86" ];
    });
    host = "127.0.0.1";
    port = 9931;
    # Multi-model sleep-swap (changed 2026-10-31): six more models are declared
    # below, so only lumimaid-8b stays resident. The rest load on first request
    # and unload after 30 min idle — the 12 GB VRAM cannot hold a second
    # resident model (lumimaid Q6_K ~7.6 GB active + Breeze ~3 GB leaves ~1.7 GB
    # free). Cost: lumimaid now sleeps too. Measured 2026-10-21: waking a slept
    # model costs 28.2 s on the next request (/mnt/data re-reads the weights)
    # against ~3 s resident. Previously null (always resident) when lumimaid
    # was the only model.
    router.idleUnloadSeconds = 1800;

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
        # Penalty window: llama-server only applies presence/frequency penalties
        # to the last N tokens (`--repeat-last-n`, default 64). Group chats echo
        # same-speaker turns from hundreds of tokens back, which a 64-token window
        # never sees — widened 2026-10-31 after byte-identical replies repeated
        # despite nonzero penalties (see GOTCHAS entry).
        "repeat-last-n" = "2048";
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

    # ── Personal Favorites (Lewdiculous collection) ──────────────────────
    # Six more models from https://huggingface.co/collections/Lewdiculous/personal-favorites
    # (the seventh entry is the lumimaid-8b above). Only lumimaid-8b is
    # primary/resident; these load on first request and sleep after
    # router.idleUnloadSeconds. Weights are operator-managed like lumimaid-8b
    # (a 5–7 GB GGUF in /nix/store would pin root disk): curl each file to
    # /mnt/data/llama/ once with the command in its comment, then rebuild.
    # The service fails to start a model whose file is missing, so land the
    # weights before flipping that model on in the UI.
    # Serving moved to Ollama 2026-10-31 (see my.services.ollama above): the
    # section ids below are INERT reference. To use a model in SillyTavern,
    # type its Ollama name (safeName) into the connection profile's model field.
    models.stheno-8b = {
      # Sao10K RP specialist (Llama-3 8B; 98 likes, most-liked in the
      # collection). Same VRAM class as lumimaid-8b. One-time fetch:
      #   curl -L -o /mnt/data/llama/stheno-8b-Q6_K-imat.gguf \
      #     https://huggingface.co/Lewdiculous/L3-8B-Stheno-v3.1-GGUF-IQ-Imatrix/resolve/main/L3-8B-Stheno-v3.1-Q6_K-imat.gguf
      weights.path = "/mnt/data/llama/stheno-8b-Q6_K-imat.gguf";
      ctxSize = 8192; # GGUF metadata context_length
      loadOnStartup = false; # on demand; sleeps after idleUnloadSeconds
      args = {
        ngl = "all";
        "flash-attn" = "on";
        "repeat-last-n" = "2048"; # see lumimaid-8b above
        # No chat-template-file override: unlike lumimaid-8b v0.1 (whose
        # metadata stores the bare name `llama3`), this GGUF carries the full
        # Llama-3 jinja in metadata. If replies degenerate to literal template
        # text, copy the override pattern from lumimaid-8b.
      };
    };
    models.lumimaid-v2-8b = {
      # Llama-3.1 successor to lumimaid-8b (NeverSleep/Lumimaid-v0.2-8B). Card
      # note: "recommended to use lower temperatures" — hence temp 0.8 in
      # the catalog preset below. One-time fetch:
      #   curl -L -o /mnt/data/llama/lumimaid-v2-8b-Q6_K-imat.gguf \
      #     https://huggingface.co/Lewdiculous/Lumimaid-v0.2-8B-GGUF-IQ-Imatrix/resolve/main/Lumimaid-v0.2-8B-Q6_K-imat.gguf
      weights.path = "/mnt/data/llama/lumimaid-v2-8b-Q6_K-imat.gguf";
      # Metadata claims 131072 (Llama-3.1 native max) but it trained on 8k
      # LimaRP data; KV cache at 131k would OOM instantly. 8192 = trained ctx.
      ctxSize = 8192;
      loadOnStartup = false;
      args = {
        ngl = "all";
        "flash-attn" = "on";
        "repeat-last-n" = "2048";
        # Same as stheno-8b: full Llama-3 jinja ships in GGUF metadata.
      };
    };
    models.kunoichi-7b = {
      # Lewdiculous's own "recommended small model" (Mistral 7B DPO). Fastest
      # of the set. NOTE the filename uses `-imatrix`, not `-imat`. Fetch:
      #   curl -L -o /mnt/data/llama/kunoichi-7b-Q6_K-imatrix.gguf \
      #     https://huggingface.co/Lewdiculous/Kunoichi-DPO-v2-7B-GGUF-Imatrix/resolve/main/Kunoichi-DPO-v2-7B-Q6_K-imatrix.gguf
      weights.path = "/mnt/data/llama/kunoichi-7b-Q6_K-imatrix.gguf";
      ctxSize = 8192; # GGUF metadata context_length
      loadOnStartup = false;
      args = {
        ngl = "all";
        "flash-attn" = "on";
        "repeat-last-n" = "2048";
        # Mistral instruct template ships in GGUF metadata ([INST]..[/INST]);
        # no override file exists for this family — llama.cpp built-ins render
        # it. Same fallback advice as above if output looks templated.
      };
    };
    models.infinityrp-7b = {
      # Anti-hallucination design (waits for user instead of deciding for them;
      # Eris_Floramix_DPO × Datura merge, Mistral 7B). Matches the desktop's
      # existing Ollama reference (same repo + quant). Fetch:
      #   curl -L -o /mnt/data/llama/infinityrp-7b-Q4_K_M-imat.gguf \
      #     https://huggingface.co/Lewdiculous/InfinityRP-v1-7B-GGUF-IQ-Imatrix/resolve/main/InfinityRP-v1-7B-Q4_K_M-imat.gguf
      weights.path = "/mnt/data/llama/infinityrp-7b-Q4_K_M-imat.gguf";
      # Card note states 8192 supported; metadata claims 32768. 8192 keeps KV
      # small and matches the desktop profile.
      ctxSize = 8192;
      loadOnStartup = false;
      args = {
        ngl = "all";
        "flash-attn" = "on";
        "repeat-last-n" = "2048";
        # Mistral merge; template from GGUF metadata as with kunoichi-7b.
      };
    };
    models.eris-violet-12b = {
      # Best-reviewed 12B in the collection (Mistral Nemo; "writes well, not
      # sloppy"). Ships an in-repo ST formatting preset
      # (SillyTavern-formatting-2024-12-19-by-Nitral-AI.json) plus linked ST
      # presets in the collection note. NOT the `ARM-`-prefixed file (ARM-CPU
      # specific) — the plain Q4_K_M. Fetch:
      #   curl -L -o /mnt/data/llama/eris-violet-12b-Q4_K_M-imat.gguf \
      #     https://huggingface.co/Lewdiculous/Captain-Eris_Violet-V0.420-12B-GGUF-ARM-Imatrix/resolve/main/Captain-Eris_Violet-V0.420-12B-Q4_K_M-imat.gguf
      weights.path = "/mnt/data/llama/eris-violet-12b-Q4_K_M-imat.gguf";
      # Nemo native max is huge; trained ctx unstated — 8192 is the safe pick
      # (~1.5 GB KV at Q4, fits alongside Breeze's ~3 GB when swapped in).
      ctxSize = 8192;
      loadOnStartup = false;
      args = {
        ngl = "all";
        "flash-attn" = "on";
        "repeat-last-n" = "2048";
        # Nemo Mistral template ships in GGUF metadata; no override file.
      };
    };
    models.lumimaid-v2-12b = {
      # 12B Mistral Nemo flavor; collection note: fewer refusals on extreme
      # content than the 8B. Same VRAM math as eris-violet-12b. Fetch:
      #   curl -L -o /mnt/data/llama/lumimaid-v2-12b-Q4_K_M-imat.gguf \
      #     https://huggingface.co/Lewdiculous/Lumimaid-v0.2-12B-GGUF-IQ-Imatrix/resolve/main/Lumimaid-v0.2-12B-Q4_K_M-imat.gguf
      weights.path = "/mnt/data/llama/lumimaid-v2-12b-Q4_K_M-imat.gguf";
      ctxSize = 8192;
      loadOnStartup = false;
      args = {
        ngl = "all";
        "flash-attn" = "on";
        "repeat-last-n" = "2048";
        # Nemo Mistral template ships in GGUF metadata; no override file.
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

  # ── SillyTavern (LLM Roleplay Frontend) — ENABLED 2026-10-31 ────────────
  # Restored on request 2026-10-31 with the llama.cpp and Breeze TTS backends
  # (was flipped to Ollama earlier the same day). To pause again flip off all
  # four switches (this `enable`, services.llama-cpp-nixos.enable,
  # services.breeze-tts-nixos.enable and the two tailscale-serve units) plus
  # the dashboard links.
  # Everything else (presets, model catalog, voices, secret wiring) is kept
  # intact so a re-enable is a flag flip, not a rewrite.
  # Previously: restored 2026-10-26 with its backends after ComfyUI was
  # turned off (the three together held ~10.2 GiB of 12 GiB). Served at
  # https://server.tail685690.ts.net:8444/ (tailnet only, see the tailscale
  # serve unit below). NOT under the Caddy /sillytavern/ subpath: with
  # accounts enabled SillyTavern 302s to a root-relative /login and its login
  # JS sets pathname = "/" on success, so a path-prefixed install drops the
  # user on the dashboard. Root-of-its-own-port has no such problem.
  # Options live under `services.sillytavern-nixos.*` — the upstream
  # github:Cairnstew/SillyTavern flake module, wrapped by
  # modules/nixos/sillytavern. The namespace is NOT `services.sillytavern`:
  # that one belongs to nixpkgs' own module, and the two cannot be enabled at
  # the same time (they share the unit, the account and the state directory).
  services.sillytavern-nixos = {
    enable = true; # re-enabled 2026-10-31 with the whole LLM/TTS stack

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

    # Point the account's Chat Completion at the local Ollama endpoint and
    # select the seeded preset, so a fresh login is already on the GGUF rather
    # than the OpenAI default.
    settings.common.oai_settings = {
      chat_completion_source = "custom";
      custom_url = "http://127.0.0.1:11434/v1";
      custom_model = defaultModel;
      preset_settings_openai = defaultModelPreset;
      openai_max_context = 8192;
      openai_max_tokens = 512;
      stream_openai = true;
      bind_preset_to_connection = true;
    };

    # Choices extension (`/cyoa`). Its settings live in
    # `extension_settings.sillytavern_choices`; define them here so the prompt
    # is versioned and survives rebuilds (the UI textarea shows this text).
    # Edit here, not in the UI: `settingsPolicy = "merge"` re-applies it.
    settings.common.extension_settings.sillytavern_choices = {
      enabled = true;
      num_responses = 5;
      response_length = 500;
      apply_wi_an = true;
      # One suggestion per LLM call: the extension loops `num_responses`
      # times with a per-slot intent/person, so the whole response is the
      # suggestion and there is no list format to parse. The extension fills
      # {{intent}}/{{person}}; SillyTavern substitutes {{user}}. Groups use
      # "any other character" rather than {{char}}, which names only one member.
      # Varying person avoids a wall of "I ..."; forbidding second person and
      # internal states keeps the buttons actionable.
      llm_prompt = ''
        Write one suggestion for what {{user}} could do or say next.

        Intent: {{intent}}.
        Write in {{person}} person.

        One sentence under 25 words: a concrete action, line of dialogue, or decision {{user}} could send. Never a thought, an internal question, or a description of the scene.

        If first person, use "I ..." as {{user}}. If third person, name {{user}} ("{{user}} ...") rather than using "he" or "she". Never use second person ("you", "your").

        Do not describe {{user}}'s feelings or physical sensations. Do not write any other character's dialogue, thoughts, or reactions, and do not have them act or react.

        Output only the suggestion, with no quotes, backticks, or commentary.
      '';
      # The old default wrapped the chosen suggestion in backticks, which
      # reads as code/quoted text to the model. Send it as a plain user turn.
      llm_prompt_impersonate = "{{suggestionText}}";
    };

    # Chat-completion wiring for the locally served GGUFs (Ollama backend).
    # `contextSize` must match my.services.ollama.models.<id>.numCtx (the
    # modules do not read each other); it becomes `openai_max_context` in the
    # generated preset. To use a non-default model, type its Ollama name
    # (safeName for pulls, e.g. hf.co-Lewdiculous-...; plain id for the local
    # lumimaid-8b) into the connection profile's model field. Sampling is a
    # Llama-3 RP baseline — the GGUF card points at Virt's SillyTavern presets
    # for the author's tuned values, which are imported in the UI if wanted.
    modelLayers = {
      enable = true;
      catalog.${lumimaidModel} = {
        contextSize = lumimaidContext;
        connection = {
          url = "http://127.0.0.1:11434/v1";
          model = lumimaidModel;
        };
        presets.openai = {
          temperature = 0.9;
          top_p = 0.95;
          top_k = 40;
          # 0.03 per the GGUF card's linked Poppy Porpoise preset (was 0.05).
          min_p = 0.03;
          top_a = 0;
          frequency_penalty = 0;
          presence_penalty = 0;
          repetition_penalty = 1.05;
          openai_max_tokens = 512;
        };
      };
      # Per-model presets for the Personal Favorites Ollama entries
      # (my.services.ollama.models) above. contextSize must equal each model's
      # numCtx; `model` is the Ollama safeName to type into the connection
      # profile's model field.
      # Sampling mirrors lumimaid-8b (temp 0.9 baseline) except where a card
      # note says otherwise; the Poppy card values (top_p 1, top_k 0/disabled,
      # min_p 0.03, no penalties) are tunable in the UI.
      catalog.stheno-8b = {
        contextSize = 8192;
        connection = {
          url = "http://127.0.0.1:11434/v1";
          model = "hf.co-Lewdiculous-L3-8B-Stheno-v3.1-GGUF-IQ-Imatrix-Q6_K-imat";
        };
        presets.openai = {
          temperature = 0.9;
          top_p = 0.95;
          top_k = 40;
          min_p = 0.03;
          top_a = 0;
          frequency_penalty = 0;
          presence_penalty = 0;
          repetition_penalty = 1.05;
          openai_max_tokens = 512;
        };
      };
      catalog.lumimaid-v2-8b = {
        contextSize = 8192;
        connection = {
          url = "http://127.0.0.1:11434/v1";
          model = "hf.co-Lewdiculous-Lumimaid-v0.2-8B-GGUF-IQ-Imatrix-Q6_K-imat";
        };
        presets.openai = {
          # Card note: "recommended to use lower temperatures".
          temperature = 0.8;
          top_p = 0.95;
          top_k = 40;
          min_p = 0.03;
          top_a = 0;
          frequency_penalty = 0;
          presence_penalty = 0;
          repetition_penalty = 1.05;
          openai_max_tokens = 512;
        };
      };
      catalog.kunoichi-7b = {
        contextSize = 8192;
        connection = {
          url = "http://127.0.0.1:11434/v1";
          model = "hf.co-Lewdiculous-Kunoichi-DPO-v2-7B-GGUF-Imatrix-Q6_K-imatrix";
        };
        presets.openai = {
          temperature = 0.9;
          top_p = 0.95;
          top_k = 40;
          min_p = 0.03;
          top_a = 0;
          frequency_penalty = 0;
          presence_penalty = 0;
          repetition_penalty = 1.05;
          openai_max_tokens = 512;
        };
      };
      catalog.infinityrp-7b = {
        contextSize = 8192;
        connection = {
          url = "http://127.0.0.1:11434/v1";
          model = "hf.co-Lewdiculous-InfinityRP-v1-7B-GGUF-IQ-Imatrix-Q4_K_M-imat";
        };
        presets.openai = {
          temperature = 0.9;
          top_p = 0.95;
          top_k = 40;
          min_p = 0.03;
          top_a = 0;
          frequency_penalty = 0;
          presence_penalty = 0;
          repetition_penalty = 1.05;
          openai_max_tokens = 512;
        };
      };
      catalog.eris-violet-12b = {
        contextSize = 8192;
        connection = {
          url = "http://127.0.0.1:11434/v1";
          model = "hf.co-Lewdiculous-Captain-Eris_Violet-V0.420-12B-GGUF-ARM-Imatrix-Q4_K_M-imat";
        };
        presets.openai = {
          temperature = 0.9;
          top_p = 0.95;
          top_k = 40;
          min_p = 0.03;
          top_a = 0;
          frequency_penalty = 0;
          presence_penalty = 0;
          repetition_penalty = 1.05;
          openai_max_tokens = 512;
        };
      };
      catalog.lumimaid-v2-12b = {
        contextSize = 8192;
        connection = {
          url = "http://127.0.0.1:11434/v1";
          model = "hf.co-Lewdiculous-Lumimaid-v0.2-12B-GGUF-IQ-Imatrix-Q4_K_M-imat";
        };
        presets.openai = {
          temperature = 0.9;
          top_p = 0.95;
          top_k = 40;
          min_p = 0.03;
          top_a = 0;
          frequency_penalty = 0;
          presence_penalty = 0;
          repetition_penalty = 1.05;
          openai_max_tokens = 512;
        };
      };
      # DS-R1 Qwen3-8B RpR v4 (reasoning). Sampling + reasoning setup per the
      # model card "Recommended Samplers" + "How to use reasoning models
      # correctly in ST" (ArliAI/DS-R1-Qwen3-8B-ArliAI-RpR-v4-Small): temp 1.0,
      # min_p 0.02, top_k 40, 2048+ tokens, NO rep-penalty samplers (the card
      # explicitly warns against them, so this preset sets none at all — not
      # even 0.0); reasoning prefix/suffix exactly <think>/</think>; instruct
      # pins names_behavior none (card: include-names must be never, no
      # char-name appending — the remaining two toggles are global power_user
      # UI settings, deliberately not forced here so the other models keep
      # their behavior). contextSize must match the Modelfile numCtx above
      # (16000, the card's 16K training length).
      catalog.ds-r1 = {
        contextSize = 16000;
        connection = {
          url = "http://127.0.0.1:11434/v1";
          model = "hf.co-Lewdiculous-DS-R1-Qwen3-8B-ArliAI-RpR-v4-Small-GGUF-IQ-Imatrix-Q4_K_M-imat";
        };
        presets.openai = {
          temperature = 1.0;
          top_p = 1.0;
          top_k = 40;
          min_p = 0.02;
          top_a = 0;
          openai_max_tokens = 2048;
        };
        presets.reasoning = {
          prefix = "<think>";
          suffix = "</think>";
          separator = "\n";
        };
        presets.sysprompt = {
          content = ''You are a roleplaying AI with deep reasoning capabilities, based on the ArliAI RpR v4 model. Use <think> </think> tags for internal reasoning before responding. Stay in character and write creatively, responding from {{char}}'s perspective. Follow the character description and scenario closely.'';
        };
        presets.context = {
          story_string = "{{#if system}}{{system}}\n{{/if}}{{#if wiBefore}}{{wiBefore}}\n{{/if}}{{#if description}}{{description}}\n{{/if}}{{#if personality}}{{char}}'s personality: {{personality}}\n{{/if}}{{#if scenario}}Scenario: {{scenario}}\n{{/if}}{{#if wiAfter}}{{wiAfter}}\n{{/if}}{{#if persona}}{{persona}}\n{{/if}}";
          example_separator = "***";
          chat_start = "***";
          use_stop_strings = true;
          names_as_stop_strings = true;
          always_force_name2 = false;
        };
        presets.instruct = {
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
    users.seanc = {
      name = "Sean";
      admin = true;
      passwordFile = config.age.secrets."sillytavern-password".path;
    };

    # ── Character-card generator (sillytavern-mkchar) ────────────────────
    # Guided CLI that drafts a TavernCard v2 from a fixed questionnaire.
    # `charGen.endpoint = null` resolves at build time: llama.cpp's router
    # when services.llama-cpp-nixos.enable is set (it is not — Ollama owns
    # the GPU), else Ollama at http://127.0.0.1:11434/v1. `model` must name
    # an Ollama tag/safeName; the upstream default `llama3.1` is not pulled
    # on this host, so bind it to the same Lumimaid v0.2 the chat profile
    # uses. No apiKeyFile: the loopback Ollama endpoint takes no token.
    charGen = {
      enable = true;
      model = defaultModel;
    };

    # Extensions/plugins are pinned store paths; the UI's update button would
    # fail against a read-only path. (Also forced off upstream when any are
    # declared; spelled out for the record.)
    config.extensions.autoUpdate = false;

    # ── Third-party extensions ───────────────────────────────────────────
    # Installed as pinned store paths under the package's third-party
    # directory; bump `rev` and rebuild to update.
    extensions = {
      # Agentic character memory (POV-aware, witness tracking, relationship
      # dynamics). https://github.com/unkarelian/openvault
      openvault = {
        url = "https://github.com/unkarelian/openvault";
        rev = "7138733193407de4e70e297a056fccff4eb1be1c";
        # fetchgit is fixed-output: without a hash it builds with a fake hash
        # and reports the real one (nix run failure 2026-10-31).
        fetchgitExtra.hash = "sha256-oo/hzRzbNH0bXdME99UeyXok8wkQzowykOyAUiDfk8A=";
      };

      # CHUB card search ships with the upstream fork (its server-side proxy
      # plugin + vendored third-party extension), not through this list.

      # Story suggestions (/cyoa) ship with the upstream fork too: the
      # vendored copy fixes a positional generateQuietPrompt call that had
      # apply_wi_an inverted and response_length ignored.
      # https://github.com/RPFiend/SillyTavern-Choices
    };

    # No `systemdOverrides` any more. Both raw-unit escapes were upstream
    # defects, fixed in 6cee6f7: the hardening list no longer sets
    # `MemoryDenyWriteExecute` (V8 JIT needs W+X pages; node died at isolate
    # init with SIGTRAP), and `ExecStart` is one `escapeShellArgs` string
    # instead of a list that rendered as three `ExecStart=` lines.
  };

  # The agenix manifest chowns sillytavern-password to the service account.
  # Kept as `mkDefault` definitions so they merge with the enabled upstream
  # module's identical ones (and still exist while the service is off, which
  # avoids "chown: invalid user" at activation).
  users.groups.sillytavern = { };
  users.users.sillytavern = {
    isSystemUser = lib.mkDefault true;
    group = lib.mkDefault "sillytavern";
    description = lib.mkDefault "SillyTavern LLM front-end server";
    home = lib.mkDefault "/var/empty";
    shell = lib.mkDefault "${pkgs.bash}/bin/bash";
  };

  # SillyTavern is served at the root of its own tailnet HTTPS port, so the
  # wrapper's Caddy /sillytavern/ upstream (and its root-relative asset
  # handles) would only advertise a broken link on the dashboard.
  my.services.proxy.upstreams.sillytavern.enable = false;

  # …so SillyTavern and opencode web are listed as direct cards instead.
  # The Breeze TTS card was dropped 2026-11-03 with the backend (see below).
  # servePort makes the dashboard link to
  # https://<current-host>:<port>/ unless it is being viewed from localhost.
  my.services.proxy.dashboard.links = [
    {
      label = "SillyTavern";
      description = "Roleplay frontend — local Ollama model (${lumimaidModel})";
      href = "http://localhost:8000/";
      servePort = 8444;
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
    # Disabled 2026-11-03 on request (frees ~3.1 GiB of the 12 GiB GPU).
    # Everything below — model pin, voices, GPU budget — is kept intact so a
    # re-enable is a flag flip plus the tailnet unit further down. Remember
    # the persistent `tailscale serve` mappings: a disabled unit does not
    # reliably clear 8445/8446 (GOTCHAS.md, stack-shutdown entry).
    enable = false;

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
    # Same measurement as the LLM above: a reload costs ~6-7 s (8.1 s for the
    # first 1-line request) and skips the voice it was about to speak, so it is
    # a mid-conversation stall rather than a background saving. Residency is
    # already covered by the static budget below.
    idleUnloadSeconds = null;

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
    #
    # 2026-10-26: the remaining hero voices are committed blobs next to this
    # file (built from wiki quote references with `ovl build` +
    # `export-breeze --server`, then encoded by breeze-tts). They are local
    # because the pinned overwatch-voice-lines input stops at the original
    # eight packs. Bastion and Vendetta are omitted: Bastion's clips carry only
    # context labels ("(allies)") instead of a transcript, and Vendetta yields
    # 3.8 s of usable speech against Breeze's 5 s reference minimum.
    voices =
      lib.genAttrs
        [ "Ana" "Cassidy" "Mercy" "Moira" "Reaper" "Sombra" "Tracer" ]
        (name: {
          source =
            flake.inputs.overwatch-voice-lines.packages.${pkgs.stdenv.hostPlatform.system}."${lib.toLower name}-voice";
        })
      // lib.genAttrs
        [
          "Anran"
          "Ashe"
          "Baptiste"
          "Brigitte"
          "Doomfist"
          "DVa"
          "Echo"
          "Emre"
          "Freja"
          "Genji"
          "Hanzo"
          "Hazard"
          "Illari"
          "JunkerQueen"
          "Junkrat"
          "Juno"
          "Kiriko"
          "Lifeweaver"
          "Lucio"
          "Mauga"
          "Mei"
          "Mizuki"
          "Orisa"
          "Pharah"
          "Ramattra"
          "Reinhardt"
          "Roadhog"
          "Shion"
          "Sierra"
          "Sigma"
          "Sojourn"
          "Soldier76"
          "Symmetra"
          "Torbjorn"
          "Venture"
          "Winston"
          "WreckingBall"
          "Wuyang"
          "Zarya"
          "Zenyatta"
        ]
        (name: { source = ./voices/${name}.breeze; })
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
  # flips `extension_settings.tts.enabled`. Inert while the service is off.
  services.sillytavern-nixos.tts.enable = false; # off 2026-11-03 with the backend
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
  # Turning the backend off removes the generated `extension_settings.tts`
  # block (the module only writes it when it has an endpoint), so the accounts'
  # saved `settings.json` would keep `enabled = true` and point at a dead
  # endpoint. `settings.json` is the one seeded file that is DEEP-MERGED on
  # every activation (scripts/st_seed_files.py), so declaring the off state here
  # reaches existing accounts too, not just newly seeded ones.
  services.sillytavern-nixos.settingsExtra.extensionSettings.tts.enabled = false;

  # Tailnet HTTPS for the TTS UI and its WebSocket. Both are HTTP backends on
  # loopback; tailscale terminates TLS and forwards, same pattern as the two
  # services above. Separate ports because the UI dials host:ws_port directly.
  systemd.services.breeze-tts-tailnet-serve = {
    enable = false; # off 2026-11-03 with the backend
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
    enable = true; # on 2026-10-31 with the SillyTavern stack
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
  # The empty `nixpkgs.config = { };` wrapper was removed — it set nothing and
  # the global perSystem config is merged in from flake.nix.
  # allowUnfree removed — globally set in flake.nix perSystem (M4d)
  # cuda.acceptLicense removed 2026-10-16 — NVIDIA/CUDA disabled above, so
  # accepting the CUDA licence would only drag the toolkit closure back in.

}
