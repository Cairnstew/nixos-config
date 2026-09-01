# ComfyUI Development

> Skill for working with the local ComfyUI instance in this environment (project
> `.opencode/` lives in the ComfyUI data dir; this skill is only loaded when the
> agent runs from that directory).

## Instance

- **URL / API**: `http://127.0.0.1:8188` (loopback only; no auth). Web UI at the
  same address, also exposed via the tailnet reverse proxy at
  `https://server.tail685690.ts.net/comfyui/`.
- **GPU**: single NVIDIA RTX 3060 12 GB. VRAM is the hard constraint — prefer
  models/workflows sized for ≤ ~11 GB usable (SD1.5/SDXL Turbo-class unless you
  are deliberately running low-vram Flux). If VRAM pressure causes OOM/black
  images, run at lower resolution, `--lowvram` style workflows are handled by
  ComfyUI automatically; free VRAM via `/free` or the `clear_vram` MCP tool.
- **Service**: `comfy-ui.service` (user `comfy-ui`), hardening CPUQuota 400%,
  `--listen 0.0.0.0 --port 8188 --base-directory <dataDir>`.

## Data directory layout (`dataDir`)

```
dataDir/                            # /mnt/data/comfyui (0770 comfy-ui:comfy-ui)
├── models/
│   ├── checkpoints/                # drop .safetensors here (then refresh)
│   ├── loras/  vae/  clip/  unet/  diffusion_models/  upscale_models/
│   └── ...
├── output/                         # generated images land here
├── input/                          # upload images for img2img/ControlNet here
├── user/default/workflows/         # saved UI workflows (JSON, version 0.4)
├── user/default/comfy.settings.json
├── custom_nodes/                   # custom node packs (install at runtime)
└── temp/
```

The primary user (`seanc`, in the `comfy-ui` group) can read/write everything
with `0770`/`UMask 0007`; no sudo needed for normal ComfyUI work.

## API quick reference (all GET/POST to http://127.0.0.1:8188)

- `GET /system_stats` — GPU/VRAM/Python info
- `GET /queue` — running + pending prompt queue
- `GET /prompt` — currently running prompt detail
- `GET /history` — past runs (errors have full tracebacks); `?prompt_id=` for one
- `GET /object_info` — available node types (great for authoring workflows)
- `POST /prompt` — enqueue a workflow in **API format** `{ "prompt": {...}, "client_id": "..." }`
- `POST /free` — unload models (VRAM), `?unload_models=true&free_memory=true`
- `GET /models` / `GET /object_info` — what's installed
- `POST /upload/image` — stage an image into `input/`
- `POST /interrupt` — stop the running job

Workflows saved from the UI (`user/default/workflows/*.json`) are the UI format
(`nodes`/`links` arrays, `version: 0.4`). To run one via API you must convert to
API format (`{"nodeId": {"class_type": ..., "inputs": {...}}}`) — the MCP
`create_workflow`/`get_workflow` tools and the `comfyui-api` tool handle this;
for hand-authoring, consult `GET /object_info` for exact class names and input
types.

## MCP tools (server: comfyui-mcp)

A local MCP server (`comfyui-mcp`, wired in `.opencode/opencode.json`) exposes
the ComfyUI control plane as tools, including: `enqueue_workflow`,
`generate_image`, `get_system_stats`, `get_history`, `queue`, `visualize_workflow`,
`create_workflow`/`save_workflow`/`get_workflow`, `list_local_models`,
`download_model`, `upload_image`, `get_image`, `clear_vram`, `restart_comfyui`.
Prefer these over raw API calls for anything non-trivial.

## Workflow authoring rules of thumb

- Validate before running: `create_workflow` `validate` or ComfyUI's
  `/prompt` POST only accepts fully-wired API graphs (every input connected or
  with a value; missing node classes → 400 with traceback).
- Keep the RTX 3060's 12 GB in mind: defaults like `width/height 1024x1024` +
  SDXL can spike VRAM; use latent upscaling / `--lowvram` workflows when needed.
- Outputs are stored in `dataDir/output/` (with subfolders for video/SaveImage
  nodes that set them); the `get_image` tool can pull them into the chat.
- If a run fails, read `/history` (or `get_history diagnose`) for the failed
  node + traceback — it states missing models/files explicitly.