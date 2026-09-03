# ComfyUI Instance Usage & Operations

> Skill for working with the RUNNING ComfyUI deployment managed by this flake
> (`my.services.comfyui`), wherever you are (this skill ships in the main
> opencode config; use it for instance ops, generation API, model inventory,
> diagnostics, civitai, and the accompanying Neko remote browser). For editing
> the module itself see `comfyui-module-development`.

## Instance facts

- **API**: `http://127.0.0.1:8188` (loopback, no auth). Web UI same URL; proxied tailnet
  endpoints: `https://server.tail685690.ts.net/comfyui/` (Caddy), plus the civitai pack's
  root-relative `/civitai/*` routes and Neko's `/neko/` on the same tailnet host.
- **GPU**: single RTX 3060 12 GB — VRAM is the hard constraint; size workflows to ≤ ~11 GB
  usable. `/free` (or `clear_vram`) to unload models between big jobs.
- **Service**: `comfy-ui.service`, user `comfy-ui`, `--listen 0.0.0.0 --port 8188
  --base-directory /mnt/data/comfyui`. Logs: `journalctl -u comfy-ui -f`.
- **User/perms**: you (primary user) are in the `comfy-ui` group; data dir is 0770
  `comfy-ui:comfy-ui`, files stay group-readable.

## Data directory (`/mnt/data/comfyui` — 1.8 TB disk)

```
models/checkpoints/   krea2TurboFP8_krea2TURBO.safetensors            (12.0 GiB, Krea 2 TURBO fp8)
models/loras/         bloomgirls-ultrarealism-krea2_4k · cutifier_krea2
                      realism_engine_krea2_v3.1 · snofs_krea_v1_4      (all declarative, sha256-marked)
user/default/workflows/  krea2SFWNSFWUncensoredImageTo_v10.json        (113-node workflow, declarative)
output/  input/  temp/  custom_nodes/  python-site-packages/  .opencode/
```

**Declarative models** are declared in `my.services.comfyui.models`
(`configurations/nixos/server/default.nix`) by URN — download mode writes them here as real
files on boot (marker `<file>.sha256` skips re-download/hash on later boots). Anything you
drop into `models/<type>/` by hand also works; ComfyUI rescans folders on each
`/object_info`/refresh.

## API quick reference (GET/POST http://127.0.0.1:8188)

- `GET /system_stats` — GPU/VRAM/python info
- `GET /queue`, `GET /prompt` — pending/running jobs
- `GET /history` — past runs (errors: full tracebacks); `?prompt_id=` for one
- `GET /object_info` — node library (also re-lists models for loaders)
- `POST /prompt` — enqueue **API-format** workflow `{ "prompt": {...}, "client_id": "..." }`
- `POST /free` — unload VRAM, `?unload_models=true&free_memory=true`
- `GET /models` — installed model inventory
- `POST /upload/image` — stage an input image
- `POST /interrupt` — stop current job

UI-saved workflows are the UI format (`nodes`/`links`, version 0.4); to run via API convert
to `{nodeId: {class_type, inputs}}`. The `comfyui` MCP server (project-local `.opencode/`,
wired when running opencode from the data dir) provides pretty tool wrappers —
`enqueue_workflow`, `generate_image`, `get_system_stats`, `get_history`,
`create/save/get_workflow`, `list_local_models`, `download_model`, `upload_image`,
`clear_vram`, `restart_comfyui`. Prefer those in the data dir.

## Civitai integration

- **Auth**: the agenix secret `civitai-key` is POSTed to `/civitai/auth/api-key` on boot by
  the `comfy-ui-civitai-auth` oneshot and persisted to
  `$HOME/.civitai/comfy-settings.json`; status check:
  `curl -s http://127.0.0.1:8188/civitai/auth/status` → `{"authenticated": true, ...}`.
- **civitai.red** = the official NSFW-only mirror of civitai.com (same account/API). The same
  API key works there; model download URLs
  (`https://civitai.red/api/download/models/<id>?fileId=<id>`) work for public files
  anonymously and for creator-gated files with the key. No special plugin is needed.
- **Link / node pairing** is intentionally manual: open `https://link.civitai.com` (logged in)
  and paste the 6-char code into ComfyUI's Link panel — the API key does NOT pair the relay.
- **Declarative model downloads** send the key automatically for creator-gated files (curl -L
  keeps the header from leaking to the CDN).

## Neko remote browser

`/neko/` on the same host (docker container `neko`, ports 8080/52800-tcp + 52000-52100-udp).
Login `admin`/`Dannydsd11` (admin) or `user`/`KiJgohpuM7dnyWDAxBLJ` (user). WebRTC uses a
TCP mux on 52800 (icelite off) so tailnet clients with blocked UDP can still connect; a
"Disconnected Peer failed" + `DTLS not established` in the container log means the client
lost UDP — reload on a tailnet connection (TCP fallback handles DERP-relayed clients).

## Diagnostics checklist

1. Service down / crash-looping → `journalctl -u comfy-ui -n 200` (boot errors, missing
   imports, permission on `python-site-packages`).
2. Failed generation → `GET /history` for the node traceback (missing model / OOM / type
   mismatch). OOM = black/failed images → interrupt, `POST /free`, lower res.
3. Model not showing in loader → confirm the real file exists in `models/<type>/` (not a
   dangling symlink), is owned `comfy-ui` (0664), and refresh; check
   `journalctl -u comfy-ui-prepare-dirs` for `models:` lines.
4. Manager "not available" → the `comfyui_manager` python package must be importable
   (module injects it) — a legacy git clone under `custom_nodes/` won't do.
5. Civitai gallery/catalog `JSON.parse` errors behind the proxy → the Caddy
   `handle /civitai/*` extraLocation must exist and stay multi-line.
6. Disk: models live on `/mnt/data` (1.8 T); the nix store on `/` (116 G) is NOT the place
   for GB models — prefer download mode in the module.