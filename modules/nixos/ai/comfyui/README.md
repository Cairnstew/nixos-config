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
| `my.services.comfyui.enableManager` | `false` | Enable ComfyUI-Manager (`--enable-manager`, `comfyui_manager` python package) |
| `my.services.comfyui.manager.version` | `"4.2.2"` | Manager package version |
| `my.services.comfyui.manager.url/rev/sha256` | comfy-org / tag 4.2.2 | Manager source pin (release tag, not `main`) |
| `my.services.comfyui.extraArgs` | `[]` | Additional CLI arguments |
| `my.services.comfyui.customNodes` | `{}` | Declarative custom nodes (`rev`+`sha256` = locked/pure; `ref` = convenience) |
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
presets = [ "ComfyUI_essentials" "ComfyUI-Impact-Pack" "civitai_comfy_nodes" ];

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
- **ComfyUI-Manager is a python package, not a custom node.** ComfyUI 0.25.x's
`main.py` checks `importlib.util.find_spec("comfyui_manager")` when
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

**Workspace tracking**: the "workspace" is the active workflow. The plugin
injects it into every agent's system prompt (so subagents/spawned sessions know
what to work on without being told), exports it as `OPENCODE_COMFYUI_WORKSPACE`,
and the `comfyui-workspace` tool/command view or switch it. State persists in
`.opencode/workspace.json`; agents set it whenever the user names a workflow.

- Powered by the [Janrupf/stable-diffusion-webui-nix](https://github.com/Janrupf/stable-diffusion-webui-nix) flake
