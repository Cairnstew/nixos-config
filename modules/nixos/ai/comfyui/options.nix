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
        Enable ComfyUI-Manager (`--enable-manager`). Requires the Manager to be
        listed in `customNodes` as `https://github.com/ltdrdata/ComfyUI-Manager`.
      '';
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
        via `builtins.fetchGit` and symlinked into place by the service.
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
            example = "https://github.com/ltdrdata/ComfyUI-Impact-Pack";
          };
          ref = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = ''
              Git ref to checkout: branch name, tag, or commit hash.
              null = fetch default branch HEAD.
            '';
            example = "v1.0";
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
            url = "https://github.com/ltdrdata/ComfyUI-Manager";
            ref = "main";
          };
          ComfyUI-Impact-Pack = {
            url = "https://github.com/ltdrdata/ComfyUI-Impact-Pack";
            ref = "v1.0";
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
  };
}
