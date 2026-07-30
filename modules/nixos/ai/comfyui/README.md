# ComfyUI

Powerful and modular diffusion model GUI with a node-based workflow editor.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `my.services.comfyui.enable` | `false` | Enable ComfyUI service |
| `my.services.comfyui.listenHost` | `null` | Bind address (`null` = localhost, `"0.0.0.0"` = all) |
| `my.services.comfyui.port` | `8188` | Web UI port |
| `my.services.comfyui.dataDir` | `"/var/lib/comfy-ui"` | Base directory for models, outputs, custom nodes |
| `my.services.comfyui.openFirewall` | `false` | Open port in firewall |
| `my.services.comfyui.enableManager` | `false` | Enable ComfyUI-Manager (`--enable-manager`) |
| `my.services.comfyui.extraArgs` | `[]` | Additional CLI arguments |
| `my.services.comfyui.customNodes` | `{}` | Declarative custom nodes (git repos) |
| `my.services.comfyui.extraModelPaths` | `[]` | Extra model directory paths |
| `my.services.comfyui.gpu.cudaDevice` | `null` | CUDA device IDs |
| `my.services.comfyui.gpu.forceFp16` | `false` | Force FP16 precision |
| `my.services.comfyui.gpu.vram` | `null` | VRAM mode (high/low/novram) |
| `my.services.comfyui.gpu.attention` | `null` | Cross-attention implementation |
| `my.services.comfyui.gpu.previewMethod` | `null` | Preview method |

## Usage

```nix
my.services.comfyui = {
  enable = true;
  listenHost = "0.0.0.0";
  dataDir = "/mnt/data/comfyui";

  enableManager = true;
  customNodes = {
    ComfyUI-Manager = {
      url = "https://github.com/ltdrdata/ComfyUI-Manager";
      ref = "main";
    };
    ComfyUI-Impact-Pack = {
      url = "https://github.com/ltdrdata/ComfyUI-Impact-Pack";
    };
  };

  extraModelPaths = [
    {
      name = "shared";
      basePath = "/mnt/storage";
      paths = {
        checkpoints = "models/checkpoints";
        loras = "models/loras";
      };
    }
  ];
};
```

## Notes

- Requires NVIDIA GPU with CUDA (uses `pkgs.stable-diffusion-webui.comfy.cuda`)
- Custom nodes are fetched via `builtins.fetchGit` at build time and symlinked into `dataDir/custom_nodes/`
- `extraModelPaths` generates an `extra_model_paths.yaml` injected via `--extra-model-paths-config`
- Accessible at `https://server.tailscale.ts.net/comfyui/` via the proxy dashboard
- Powered by the [Janrupf/stable-diffusion-webui-nix](https://github.com/Janrupf/stable-diffusion-webui-nix) flake
