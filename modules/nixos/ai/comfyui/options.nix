{ lib, ... }:
let
  inherit (lib) mkEnableOption mkOption types;
in
{
  options.my.services.comfyui = {
    enable = mkEnableOption "ComfyUI image generation service";

    package = mkOption {
      type = types.nullOr types.package;
      default = null;
      example = lib.literalExpression ''pkgs.stable-diffusion-webui.comfy.cuda'';
      description = ''
        ComfyUI package to run. null (default) = a repo-local build pinned to
        v0.29.2 (see modules/nixos/ai/comfyui/comfy/) — the first stable line
        with native Krea 2 support (comfy/ldm/krea2 + CLIPLoader type "krea2").
        The `stable-diffusion-webui-nix` input still ships v0.25.1 which lacks
        Krea 2, so the module overrides services.comfyUi.package with the
        vendored build unless this option is set.
      '';
    };

    listenHost = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "0.0.0.0";
      description = ''
        Host address to bind the web interface to.
        null = localhost only (safe default).
        "0.0.0.0" = all interfaces (for Tailscale/proxy access).
      '';
    };

    port = mkOption {
      type = types.port;
      default = 8188;
      description = "Port for the ComfyUI web interface.";
    };

    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/comfy-ui";
      description = "Base directory for ComfyUI models, outputs, custom nodes, and config.";
    };

    openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = "Open the ComfyUI port in the firewall.";
    };

    enableManager = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Enable ComfyUI-Manager (`--enable-manager`). ComfyUI 0.25.x loads the
        Manager as the `comfyui_manager` PYTHON PACKAGE (it checks
        `find_spec("comfyui_manager")` and silently disables the flag if the
        package isn't importable) — NOT as a git clone in `customNodes` (a
        checkout there fails to import; a legacy <4.x clone that loads shows
        "ComfyUI-Manager upgrade required" because the frontend demands >= 4.2.1
        while the repo's `main` branch still carries 3.41). This module builds
        the package from `manager.*` and injects it via PYTHONPATH with only the
        small missing deps — the env's own transformers/huggingface-hub are kept.
      '';
    };

    manager = {
      version = mkOption {
        type = types.str;
        default = "4.2.2";
        description = "comfyui_manager package version (pyproject.toml).";
      };
      url = mkOption {
        type = types.str;
        default = "https://github.com/comfy-org/ComfyUI-Manager";
        description = "Git URL of the ComfyUI-Manager source.";
      };
      rev = mkOption {
        type = types.nullOr types.str;
        default = "bd4ede2237c97b3a71569a0301a0be9db226c7e9";
        description = ''
          Commit to pin (release TAG, not `main` — main lags at 3.41 and fails
          the frontend's >= 4.2.1 check). null = builtins.fetchGit (impure).
        '';
        example = "bd4ede2237c97b3a71569a0301a0be9db226c7e9"; # tag 4.2.2
      };
      sha256 = mkOption {
        type = types.nullOr types.str;
        default = "025x656cdg1izjabm93cgxxzzll95lzgdwk82m809p33wd382xbj";
        description = "sha256 from `nix-prefetch-git <url> <rev>` (locked fetch).";
      };
    };

    extraArgs = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [ "--highvram" "--auto-launch" ];
      description = "Additional CLI arguments passed to ComfyUI.";
    };

    civitaiApiKeyPath = mkOption {
      type = types.nullOr types.path;
      default = null;
      example = lib.literalExpression ''config.age.secrets."civitai-key".path'';
      description = ''
        Path to a file containing a Civitai API key (usually an agenix secret
        decrypted at `/run/agenix/<name>`). When set, a `comfy-ui-civitai-auth`
        oneshot registers the key with the `civitai-comfy-nodes` pack after
        ComfyUI starts, by POSTing it to `/civitai/auth/api-key` (the pack
        validates it against Civitai and persists it to a writable
        `$HOME/.civitai/comfy-settings.json`). The key unlocks authenticated
        searches/generation with the official orchestration pack and avoids the
        anonymous API's low rate limits.
      '';
    };

    customNodes = mkOption {
      description = ''
        Declarative custom nodes for ComfyUI. Each attribute name becomes the
        directory name under `custom_nodes/`. Repos are fetched at build time
        and symlinked into place by the service.

        Two fetch modes:
        - **Locked (recommended):** set both `rev` and `sha256` → `pkgs.fetchgit`
          (a pure derivation fetch, no eval-time network). Required for hosts
          deployed with a plain `nixos-rebuild switch` / `nix run .#activate`.
          Get the values with `nix-prefetch-git <url> <rev>`.
        - **Convenience:** only `url` (and optionally `ref`) → `builtins.fetchGit`
          at eval time (no hashes to compute, but impure: needs network during
          eval, breaks pure activation — only usable with `--impure`).

        NOTE: do NOT list ComfyUI-Manager here — since v4.x it must be installed
        as the `comfyui_manager` python package (see `enableManager` / `manager`).
      '';
      type = types.attrsOf (types.submodule {
        options = {
          enable = mkOption {
            type = types.bool;
            default = true;
            description = "Enable this custom node.";
          };
          url = mkOption {
            type = types.str;
            description = "Git URL of the custom node repository.";
            example = "https://github.com/comfy-org/ComfyUI-Manager";
          };
          ref = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = ''
              Git ref to checkout: branch name or tag. Only used in the
              convenience (`builtins.fetchGit`) mode.
              null = fetch default branch HEAD.
            '';
            example = "v1.0";
          };
          rev = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = ''
              Exact commit to pin (full or short hash). Must be set together
              with `sha256` — together they switch the fetch to `pkgs.fetchgit`
              (pure, locked, reproducible). Obtain from `nix-prefetch-git`.
            '';
            example = "bd4ede2237c97b3a71569a0301a0be9db226c7e9";
          };
          sha256 = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = ''
              `"sha256"` (base32) printed by `nix-prefetch-git <url> <rev>`.
              Must be set together with `rev`. null = builtins.fetchGit
              (impure) mode.
            '';
            example = "025x656cdg1izjabm93cgxxzzll95lzgdwk82m809p33wd382xbj";
          };
          fetchSubmodules = mkOption {
            type = types.bool;
            default = true;
            description = "Fetch git submodules recursively.";
          };
        };
      });
      default = { };
      example = lib.literalExpression ''
        {
          ComfyUI-Manager = {
            url = "https://github.com/comfy-org/ComfyUI-Manager";
            rev = "bd4ede2237c97b3a71569a0301a0be9db226c7e9"; # tag 4.2.2
            sha256 = "025x656cdg1izjabm93cgxxzzll95lzgdwk82m809p33wd382xbj";
          };
          ComfyUI-Impact-Pack = {
            url = "https://github.com/ltdrdata/ComfyUI-Impact-Pack";
            ref = "v1.0";
          };
        }
      '';
    };

    presets = mkOption {
      description = ''
        Enable curated custom nodes from the built-in catalog
        (`modules/nixos/ai/comfyui/catalog.nix`) by name. Each catalog entry is
        a pure, locked fetch (`url` + `rev` + `sha256`, prefetched with
        `nix-prefetch-git --url <url> --fetch-submodules`), so presets work with
        a plain `nixos-rebuild switch` / `nix run .#activate`.

        Valid names (see catalog.nix for descriptions):
        ${lib.concatStringsSep ", " (map (n: "`${n}`") (lib.attrNames (import ./catalog.nix)))}

        An explicit `customNodes` entry with the same attr name replaces the
        catalog pin entirely for that name (use it to bump a pin or disable a
        preset member with `enable = false`).
      '';
      type = types.listOf types.str;
      default = [ ];
      example = lib.literalExpression ''[ "ComfyUI_essentials" "civitai-comfy-nodes" ]'';
    };

    models = mkOption {
      description = ''
        Declarative model downloads. Each attribute name is the file name
        (e.g. `krea2TurboFP8_krea2TURBO.safetensors`) under
        `<dataDir>/models/<type>/`. The value is either a plain URN string
        (`"urn:air:<family>:<type>:civitai:<modelId>@<versionId>[+<fileId>]"`)
        or an attrset for more control.

        Two fetch modes:
        - **download** (default when a URN is given): the file is downloaded
          at activation by `comfy-ui-prepare-dirs` straight into
          `<dataDir>/models/<type>/<filename>` — a real file on the data
          disk, resumable (`curl -C - --retry-all-errors`), verified against
          `sha256` when one is set, skipped when already verified. Use this
          for GB-scale models: nothing bloats the Nix store.
        - **store** (default for explicit `url` + `sha256`): the file is
          fetched at BUILD time with `pkgs.fetchurl` (a pure fixed-output
          derivation pinned by `sha256`) and symlinked into place. Fully
          immutable/GC-safe, but the bytes live in the store.

        URN format: `urn:air:<family>:<type>:civitai:<modelId>@<versionId>[+<fileId>]`
        e.g. `urn:air:krea2:checkpoint:civitai:2723583@3060999+2939623` maps to
        the civitai.red download URL for version 3060999 file 2939623 and the
        model folder for <type> (`checkpoint` → `checkpoints`,
        `lora` → `loras`, `vae` → `vae`, `clip` → `clip`,
        `diffusion_model` → `diffusion_models`, ...). Only `civitai` is
        supported as a source; the .red domain is the same API as .com and
        public model files redirect to the CDN anonymously (no API key in the
        store or config).

        Civitai's R2 delivery drops mid-stream on multi-GB files; both modes
        retry at curl level, and `download` resumes partial transfers.
      '';
      type = types.attrsOf (types.either types.str (types.submodule {
        options = {
          enable = mkOption {
            type = types.bool;
            default = true;
            description = "Enable this declarative model.";
          };
          urn = mkOption {
            type = types.nullOr types.str;
            default = null;
            example = "urn:air:krea2:checkpoint:civitai:2723583@3060999+2939623";
            description = ''
              URN identifying the model (see option description). Implies the
              civitai download URL, the model folder, and default mode
              `download`. Cannot be combined with `url`.
            '';
          };
          mode = mkOption {
            type = types.nullOr (types.enum [ "store" "download" ]);
            default = null;
            description = ''
              Where the bytes live: `store` = build-time fetchurl into the
              Nix store + symlink (needs `sha256`); `download` = resumable
              curl into `<dataDir>/models/<type>/` at activation.
              null = `download` for URN-defined entries, `store` otherwise.
            '';
          };
          type = mkOption {
            type = types.nullOr types.str;
            default = null;
            example = "checkpoints";
            description = ''
              ComfyUI model folder under `<dataDir>/models/` (checkpoints,
              loras, vae, clip, diffusion_models, ...). Default derives from
              the URN `<type>` word. Required when no URN is given.
            '';
          };
          url = mkOption {
            type = types.nullOr types.str;
            default = null;
            example = "https://civitai.com/api/download/models/3060999?fileId=2939623";
            description = "Direct download URL. Default derives from the URN. Cannot be combined with `urn`.";
          };
          sha256 = mkOption {
            type = types.nullOr types.str;
            default = null;
            example = "0kpn616i57djdz1ib2851jjrf4jrnjws3jafbmg9dpsrgi826d9d";
            description = ''
              sha256 (base32) of the downloaded file. REQUIRED in `store`
              mode. In `download` mode optional but recommended: the file is
              verified against it after download and on later boots (a marker
              skipping re-verification once known-good).
            '';
          };
        };
      }));
      default = { };
      example = lib.literalExpression ''
        {
          # URN shorthand → downloaded to dataDir/models/checkpoints/ on the
          # data disk, resumable + hash-verified once sha256 is set.
          "krea2TurboFP8_krea2TURBO.safetensors" = {
            urn = "urn:air:krea2:checkpoint:civitai:2723583@3060999+2939623";
            sha256 = "0kpn616i57djdz1ib2851jjrf4jrnjws3jafbmg9dpsrgi826d9d";
          };
          # Plain string = the same thing (download mode, no hash yet).
          "flux1-dev.safetensors" = "urn:air:flux:checkpoint:civitai:133005@183639";
          # Store mode: pure build-time fetch pinned by hash.
          "sd_xl_base.safetensors" = {
            type = "checkpoints";
            url = "https://civitai.com/api/download/models/199240?fileId=222795";
            sha256 = "0z15a2kbrg0djl5w70h6gd7kyaw7hcvpwinpvbsdfjb80hc70n0k";
          };
        }
      '';
    };

    extraModelPaths = mkOption {
      description = ''
        Extra model directory paths registered via `extra_model_paths.yaml`.
        Each entry maps a folder type (checkpoints, loras, vae, etc.) to
        one or more filesystem paths. Useful for sharing models across
        different tools or mounting external storage.
      '';
      type = types.listOf (types.submodule {
        options = {
          name = mkOption {
            type = types.str;
            description = "Section name (e.g. 'shared-models', 'a1111').";
          };
          basePath = mkOption {
            type = types.nullOr types.path;
            default = null;
            description = ''
              Base path for resolving relative directory entries.
              If null, paths are used as-is (absolute).
            '';
          };
          isDefault = mkOption {
            type = types.bool;
            default = false;
            description = "Mark these folders as the default for model downloads.";
          };
          paths = mkOption {
            type = types.attrsOf (types.either types.path (types.listOf types.path));
            description = "Mapping of folder type to absolute path or list of paths.";
            example = {
              checkpoints = "/mnt/storage/models/checkpoints";
              loras = [ "/mnt/storage/loras" "/other/loras" ];
            };
          };
        };
      });
      default = [ ];
      example = lib.literalExpression ''
        [
          {
            name = "shared-models";
            basePath = "/mnt/storage";
            paths = {
              checkpoints = "models/checkpoints";
              loras = "models/loras";
            };
          }
        ]
      '';
    };

    gpu = {
      cudaDevice = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "0";
        description = "CUDA device IDs to use (comma-separated). null = auto.";
      };
      forceFp16 = mkOption {
        type = types.bool;
        default = false;
        description = "Force FP16 precision.";
      };
      vram = mkOption {
        type = types.nullOr (types.enum [ "high" "low" "novram" ]);
        default = null;
        description = "VRAM management mode. null = default behavior.";
      };
      attention = mkOption {
        type = types.nullOr (types.enum [ "split" "quad" "pytorch" "sage" "flash" ]);
        default = null;
        description = "Cross-attention implementation to use.";
      };
      previewMethod = mkOption {
        type = types.nullOr (types.enum [ "none" "auto" "latent2rgb" "taesd" ]);
        default = null;
        description = "Preview method for image generation.";
      };
    };

    opencode = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Write a project-local opencode config (`.opencode/`) into the ComfyUI
          data dir with ComfyUI skills/commands/tools and an MCP server. Only
          loaded when opencode runs from the data dir — the tools never appear
          in other projects (e.g. nixos-config) for cleanliness. Wired only
          when opencode is enabled for the primary user.
        '';
      };
      skills = mkOption {
        type = types.attrsOf types.str;
        description = ''
          Custom opencode skills contributed by this module (name → SKILL.md
          markdown). These render into the PRIMARY user's MAIN opencode config
          (`my.programs.opencode.skills`), i.e. alongside the other custom
          skills in `~/.config/opencode/skills/`, so they load in ANY project:
          `comfyui-module-development` (developing this NixOS module; models by
          URN, modes, activation, gotchas) and `comfyui-instance-usage`
          (operating the running instance: API, data dir, civitai, diagnostics).
          The dataDir project-local `.opencode/` (skill `comfyui-development`)
          remains separate and scoped to sessions started inside the data dir.
        '';
        default = {
          comfyui-module-development = builtins.readFile ./opencode/skills/comfyui-module-development.md;
          comfyui-instance-usage = builtins.readFile ./opencode/skills/comfyui-instance-usage.md;
        };
        example = lib.literalExpression ''
          { "comfyui-module-development" = builtins.readFile ./opencode/skills/comfyui-module-development.md; }
        '';
      };
      mcp = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Add a local MCP server entry to the project opencode.json.";
        };
        name = mkOption {
          type = types.str;
          default = "comfyui";
          description = "MCP server name in the opencode config.";
        };
        command = mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = ''
            Command (+ args) that starts the MCP server. Empty (default) =
            `npx -y comfyui-mcp@0.52.167` (artokun/comfyui-mcp, local-first,
            drives this instance; biggest tool surface). The default is wrapped
            in a script that prepends `nodejs` to PATH — the npx-downloaded
            binary is `#!/usr/bin/env node` and fails to spawn without node on
            PATH. Set your own to use e.g. `[ "uvx" "comfy-mcp" ]` (Comfy-Org
            official server) or an absolute path to a venv/script.
          '';
        };
        environment = mkOption {
          type = types.attrsOf types.str;
          default = { };
          description = "Extra environment variables for the MCP server process.";
        };
      };
    };
  };
}
