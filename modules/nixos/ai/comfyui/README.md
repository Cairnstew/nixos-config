# ComfyUI

Powerful and modular diffusion model GUI with a node-based workflow editor.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `my.services.comfyui.enable` | `false` | Enable ComfyUI service |
| `my.services.comfyui.package` | `null` | ComfyUI package. null = repo-local **v0.29.2** build (see `comfy/`) — first stable line with native Krea 2 (`CLIPLoader type="krea2"`); override to use e.g. `pkgs.stable-diffusion-webui.comfy.cuda` (input's v0.25.1) |
| `my.services.comfyui.listenHost` | `null` | Bind address (`null` = localhost, `"0.0.0.0"` = all) |
| `my.services.comfyui.port` | `8188` | Web UI port |
| `my.services.comfyui.dataDir` | `"/var/lib/comfy-ui"` | Base directory for models, outputs, custom nodes |
| `my.services.comfyui.openFirewall` | `false` | Open port in firewall |
| `my.services.comfyui.enableManager` | `false` | Enable ComfyUI-Manager (`--enable-manager`, `comfyui_manager` python package) |
| `my.services.comfyui.manager.version` | `"4.2.2"` | Manager package version |
| `my.services.comfyui.manager.url/rev/sha256` | comfy-org / tag 4.2.2 | Manager source pin (release tag, not `main`) |
| `my.services.comfyui.extraArgs` | `[]` | Additional CLI arguments |
| `my.services.comfyui.customNodes` | `{}` | Declarative custom nodes (`rev`+`sha256` = locked/pure; `ref` = convenience) |
| `my.services.comfyui.models` | `{}` | Declarative model downloads (build-time `fetchurl` pinned by sha256, symlinked into `models/<type>/`) |
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

enableManager = true; # installs the comfyui_manager python package (4.2.2)

# Curated node set from the module's catalog — each is a locked url+rev+sha256
# fetch, safe for pure `nix run .#activate`. See catalog.nix for the full list
# and pin-bump instructions; customNodes below overrides any same-named pin.
presets = [ "ComfyUI_essentials" "ComfyUI-Impact-Pack" "civitai-comfy-nodes" ];

# Manual nodes (or overrides of catalog pins):
customNodes = {
# Declarative custom nodes — git checkouts that ComfyUI imports directly
# (must have a root __init__.py). NOTE: do NOT put ComfyUI-Manager here —
# since v4.x it is a python package, see enableManager/manager.
ComfyUI-Impact-Pack = {
url = "https://github.com/ltdrdata/ComfyUI-Impact-Pack";
ref = "v1.0";
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

# Declarative models.
# URN shorthand → download mode: real file in dataDir/models/checkpoints/ on
# the data disk, fetched at activation (resumable, sha256-verified).
models = {
"krea2TurboFP8_krea2TURBO.safetensors" = {
urn = "urn:air:krea2:checkpoint:civitai:2723583@3060999+2939623";
sha256 = "0kpn616i57djdz1ib2851jjrf4jrnjws3jafbmg9dpsrgi826d9d"; # optional but recommended
};
# A plain string is the same thing without the hash yet:
"flux1-dev.safetensors" = "urn:air:flux:checkpoint:civitai:133005@183639";
# Store mode: pure build-time fetch pinned by hash (small/immutable models).
"sd_xl_base.safetensors" = {
type = "checkpoints";
url = "https://civitai.com/api/download/models/199240?fileId=222795";
sha256 = "0z15a2kbrg0djl5w70h6gd7kyaw7hcvpwinpvbsdfjb80hc70n0k";
};
};
};
```

## Notes

- Requires NVIDIA GPU with CUDA (uses `pkgs.stable-diffusion-webui.comfy.cuda`)
- **Custom node catalog + presets**: `catalog.nix` ships a curated set of
popular packs (workflow QoL, Impact/detailers, ControlNet aux, IPAdapter,
video, captioning, GGUF, CivitAI) all pre-pinned with `url`+`rev`+`sha256`
from `nix-prefetch-git --url <url> --fetch-submodules`. Enable them with
`presets = [ "name" ... ]` — pure activation safe. `customNodes` entries
replace any same-named catalog pin entirely for that name.
- Custom nodes are symlinked into `dataDir/custom_nodes/`. Each node is fetched
in one of two modes:
- **Locked/pure (`rev` + `sha256`)** — `pkgs.fetchgit`, a derivation fetch with
no eval-time network. Works with a plain `nix run .#activate` /
`nixos-rebuild switch` (no `--impure`); `nix flake check` stays green.
Pin values from `nix-prefetch-git <url> <rev>`.
- **Convenience (`url` + optional `ref`)** — `builtins.fetchGit` at eval time.
No hashes to compute, but impure: needs network during eval and breaks pure
activation, so only usable on hosts deployed with `--impure`.
- Declaratively-pinned nodes are read-only store paths (update them by changing
the `rev`/`sha256` and rebuilding). ComfyUI-Manager, once enabled, lets you do
the opposite at runtime: install MORE custom nodes into `custom_nodes/` and
download models straight into `models/` from the UI — both directories are
writable by the service. Runtime-installed nodes (git clones in the writable
dir) get updates through the Manager, exactly as in a manual install.
- **ComfyUI core version**: the module runs a repo-local **v0.29.2** package
  (`my.services.comfyui.package` option defaults to `./comfy/`'s builder) — the
  `stable-diffusion-webui-nix` input's `main` still pins v0.25.1 which has no
  native Krea 2 support. The vendored build reuses the input's requirements
  machinery with a regenerated flexseal lock; see `comfy/README.md` for the
  upgrade procedure (prefetch hash → bump `dist.nix` rev → regen
  install-instructions via the update-helper → rebuild). The **manager** is
  still a python package, not a custom node: ComfyUI 0.25.x-era `main.py`
  checks `importlib.util.find_spec("comfyui_manager")` when
  `--enable-manager` is set and **silently disables** the flag if the package is
  absent (warning: "To use the --enable-manager feature, the comfyui-manager
  package must be installed first"). The module builds it from the `manager`
  pin (release **tag**, not `main` — main lags at 3.41 and triggers the
  frontend's "ComfyUI-Manager upgrade required (>= 4.2.1)" banner) and injects
  it via `PYTHONPATH`, propagating only the missing small deps
  (GitPython/PyGithub/toml/chardet/typing-extensions) so the service env's own
  transformers/huggingface-hub are never shadowed. A legacy <4.x clone under
  `customNodes` either fails to import on 4.x or shows the upgrade banner. The
  Manager's startup security scan and runtime node-dependency installs need a
  package manager: the module adds `pip` to the injected env and points
  `PIP_TARGET` at a writable `python-site-packages/` under `dataDir` (prepended
  to PYTHONPATH), so `pip install` from the UI writes to a writable dir instead
  of the read-only Nix store.
- **Krea 2 support**: v0.29.2 ships `comfy/ldm/krea2/` +
  `comfy/text_encoders/krea2.py`, and `CLIPLoader` accepts `type="krea2"`. The
  Krea 2 TURBO FP8 model is diffusion-model-only — provide it under
  `models/diffusion_models/` (never `checkpoints/`), the Qwen3-VL 4B text
  encoder under `models/text_encoders/`, and the Qwen image VAE under
  `models/vae/`. FP8 does **not** need `--enable-triton-backend` (that only
  accelerates the comfy-kitchen ROCm INT8 path; it's opt-in). A 12.9 GB raw-FP8
  Krea 2 exceeds 12 GB VRAM **and** a 16 GB host: generation runs CPU-offload
  and RAM-swap-thrashes. For this class of GPU, prefer a GGUF-quantized Krea 2
  (~7 GB) loaded via `UnetLoaderGGUF` (ComfyUI-GGUF preset; the module injects
  the `gguf` python module so the pack imports).
- `extraModelPaths` generates an `extra_model_paths.yaml` injected via `--extra-model-paths-config`
- **Declarative models** (`models`): each attr name is the file name under
`dataDir/models/<type>/`. Two modes:
- **download** (default for URN-defined entries) — `comfy-ui-prepare-dirs`
fetches the file at activation as a REAL file on the data disk:
`curl -C - --retry-all-errors` resumes partial transfers (civitai R2 drops
mid-stream on GB files), `sha256` (when set) is verified after download and
marker-skipped once known-good, and bytes never touch the Nix store. The
file is chowned to `comfy-ui` and `models/` contents are not chmod -R'd, so
GB-scale models stay readable without re-chmod.
- **store** (default for explicit `url`+`sha256`) — `pkgs.fetchurl` at build
time (pure fixed-output derivation) symlinked in; immutable but the bytes
live in the store.
- **URN definitions**: `urn:air:<family>:<type>:civitai:<modelId>@<versionId>[+<fileId>]`
(e.g. `urn:air:krea2:checkpoint:civitai:2723583@3060999+2939623`) maps to the
civitai.red download URL and the model folder (`checkpoint`→`checkpoints`,
`lora`→`loras`, `vae`→`vae`, `clip`→`clip`, `diffusion_model`→`diffusion_models`, …).
A plain string value is the shorthand (`"…safe…safetensors" = "urn:…"`); give
an attrset to add `sha256`, `mode`, or `type`. civitai(.com/.red) public
files redirect to the CDN anonymously — no API key in store or config.
Assertions in `tests.nix` validate URN shape, folder resolution, and that
store mode pins a hash.
- **Creator-gated models** (civitai returns `401 "requires you to be logged
in"` for anonymous downloads): set `civitaiApiKeyPath` and the `download`
mode script sends `Authorization: Bearer <key>` on the initial request —
curl's `-L` does NOT forward that header to a different redirect host, so
the key only reaches civitai, and it is read from the agenix path at runtime
by the root oneshot (nothing secret in the store or the unit script). A
failed 401 aborts the oneshot loudly (`models: FAILED to obtain …`) instead
of silently shipping a missing model.
- **Civitai authentication** (`civitaiApiKeyPath`): the service exports
`HOME=$dataDir` (the `comfy-ui` user's passwd home is the read-only `/var/empty`
— without this the civitai-comfy-nodes pack can't persist auth to
`~/.civitai/` and pip warns its cache dir is unwritable). Point
`civitaiApiKeyPath` at an agenix secret (e.g. `config.age.secrets."civitai-key".path`)
and the `comfy-ui-civitai-auth` oneshot registers the key with the pack after
startup (`POST /civitai/auth/api-key`, validates against Civitai, persists to
`$HOME/.civitai/comfy-settings.json`, idempotent across boots). The legacy
`civitai_comfy_nodes` pack is deprecated upstream and NOT in the server presets;
use the official `civitai-comfy-nodes` pack instead. The pack's link/sharing
feature needs `python-socketio[client]` at runtime (link.py imports `socketio`
guarded; without it the UI asks to "pip install python-socketio[client]") — the
module injects a Nix-built socketio env (`python-socketio` + `websocket-client`)
via PYTHONPATH whenever the pack is enabled, and registers the proxy
`extraLocations` `handle /civitai/*` so the pack's root-relative `/civitai/...`
fetches work behind the `/comfyui/` reverse proxy (Caddy's catch-all otherwise
returns an empty 404 and the gallery/catalog throw `JSON.parse: unexpected end
of data`).
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
| `.opencode/commands/comfyui-workspace.md` | `/comfyui-workspace` view/set the active workflow |
| `.opencode/tools/comfyui-api.ts` | read-only API tool (stats/queue/history/models) |
| `.opencode/tools/comfyui-workspace.ts` | get/set the active workflow (the "workspace") |
| `.opencode/plugin/comfyui-workspace.ts` | injects the active workflow into every agent's system prompt + exports `OPENCODE_COMFYUI_WORKSPACE` |
| `.opencode/workspace.json` | writable state: the currently-active workflow (`{"workflow": ..., "set_by": ..., "updated": ...}`), seeded to the most recent workflow |

Tune with `my.services.comfyui.opencode.*`:
- `opencode.enable` (default `true`) — render the `.opencode/` config at all
- `opencode.mcp.enable` (default `true`) — include the MCP `comfyui` server
- `opencode.mcp.command` (default `[]` = artokun `comfyui-mcp` via npx) — swap
the server, e.g. `[ "uvx" "comfy-mcp" ]` for the Comfy-Org official server
- `opencode.mcp.environment` — extra env vars for the MCP process
- `opencode.skills` (default = `comfyui-module-development`,
`comfyui-instance-usage`) — skills contributed to the PRIMARY user's MAIN
opencode config (`~/.config/opencode/skills/<name>/SKILL.md`, available in any
project, next to the other custom skills) when their opencode is enabled.
`comfyui-module-development` helps develop this NixOS module (models by URN,
store/download modes, activation, gotchas); `comfyui-instance-usage` helps
operate the running instance (API, data dir, civitai, diagnostics). The
dataDir `.opencode/` remains the project-local scope.

**Workspace tracking**: the "workspace" is the active workflow. The plugin
injects it into every agent's system prompt (so subagents/spawned sessions know
what to work on without being told), exports it as `OPENCODE_COMFYUI_WORKSPACE`,
and the `comfyui-workspace` tool/command view or switch it. State persists in
`.opencode/workspace.json`; agents set it whenever the user names a workflow.

- Powered by the [Janrupf/stable-diffusion-webui-nix](https://github.com/Janrupf/stable-diffusion-webui-nix) flake
