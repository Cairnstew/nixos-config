{ lib, ... }:
let
  inherit (lib) mkEnableOption mkOption types;
in
{
  options.my.services.comfyui = {
    enable = mkEnableOption "ComfyUI image generation service";

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
      example = lib.literalExpression ''[ "ComfyUI_essentials" "civitai_comfy_nodes" ]'';
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
