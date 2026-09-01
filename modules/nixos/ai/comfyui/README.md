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
- Custom nodes are fetched via `builtins.fetchGit` at build time and symlinked into `dataDir/custom_nodes/` — NOTE this makes eval impure: `enableManager`/`customNodes` break pure `nix run .#activate` (nixos-rebuild switch), so they're only usable on hosts deployed with `--impure`
- `extraModelPaths` generates an `extra_model_paths.yaml` injected via `--extra-model-paths-config`
- Accessible at `https://server.tailscale.ts.net/comfyui/` via the proxy dashboard
- The module adds the primary user (`me.username`) to the `comfy-ui` group and creates `dataDir` (`0770 comfy-ui:comfy-ui`) + user-touch subdirs (`input/`, `output/`, `user/`, `custom_nodes/`, `models/…`) via a root `comfy-ui-prepare-dirs` oneshot, so the user can browse/drop files without sudo. The service runs with `UMask=0007` so new outputs/workflows stay group-accessible. `models/` contents are intentionally not chmod -R'd (they can be GBs).

## OpenCode integration (project-local)

When opencode is enabled for the primary user, the module renders a project-local
config into `<dataDir>/.opencode/` — **only visible to opencode sessions started
inside the data dir** (e.g. `cd /mnt/data/comfyui && opencode`), never to other
projects (cleanliness, not permission):

| Path | Contents |
|------|----------|
| `.opencode/opencode.json` | local `comfyui` MCP server (`comfyui-mcp`, runtime-fetched via `npx -y comfyui-mcp@0.52.167`, `COMFYUI_URL`/`COMFYUI_PATH` wired) |
| `.opencode/skills/comfyui-development/SKILL.md` | instance/API/data-dir/VRAM guidance |
| `.opencode/commands/comfyui-status.md` | `/comfyui-status` health & GPU/queue report |
| `.opencode/commands/comfyui-workflow.md` | `/comfyui-workflow` inspect/convert/validate workflows |
| `.opencode/tools/comfyui-api.ts` | read-only API tool (stats/queue/history/models) |

Tune with `my.services.comfyui.opencode.*`:
- `opencode.enable` (default `true`) — render the `.opencode/` config at all
- `opencode.mcp.enable` (default `true`) — include the MCP `comfyui` server
- `opencode.mcp.command` (default `[]` = artokun `comfyui-mcp` via npx) — swap
  the server, e.g. `[ "uvx" "comfy-mcp" ]` for the Comfy-Org official server
- `opencode.mcp.environment` — extra env vars for the MCP process

- Powered by the [Janrupf/stable-diffusion-webui-nix](https://github.com/Janrupf/stable-diffusion-webui-nix) flake
