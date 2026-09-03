# ComfyUI Module Development

> Skill for developing and maintaining the NixOS **`my.services.comfyui`** module
> (`modules/nixos/ai/comfyui/`) in this flake. Use when adding a model, changing
> a node/preset, debugging the service/activation, or extending the module's
> options. ComfyUI *usage* on a running instance is a separate skill
> (`comfyui-instance-usage`).

## Where things live

| File | Role |
|------|------|
| `options.nix` | the module option surface (`enable`, `listenHost`, `port`, `dataDir`, `enableManager`, `manager.*`, `extraArgs`, `civitaiApiKeyPath`, `customNodes`, `presets`, `models`, `extraModelPaths`, `gpu.*`, `opencode.*`) |
| `config.nix` | all wiring: Manager-as-python-package (`comfyui_manager` via PYTHONPATH), civitai pack socketio env, custom-node fetches, **model resolution** (URN parse, store/download modes), prepare-dirs unit, civitai-auth oneshot, proxy upstream, project-local `.opencode/` |
| `catalog.nix` | pre-pinned preset node catalog (`url`+`rev`+`sha256` from `nix-prefetch-git --url <url> --fetch-submodules`) |
| `tests.nix` | module assertions (manager rev/hash pairing, civitaiApiKeyPath absolute, preset validity, **model URN shape, folder resolvability, store-mode hash requirement**) |
| `README.md` | options table + notes (declarative models, civitai auth, manager, proxy) |
| `opencode/` | project-local skills/commands/tools/plugin rendered into `<dataDir>/.opencode/` |
| `meta.nix` | module metadata |

Server wiring lives in `configurations/nixos/server/default.nix` (`my.services.comfyui = { … }`).

## Declarative models (`my.services.comfyui.models`) — the parts you'll touch most

Each attr **name = filename** under `models/<type>/` (or `user/default/workflows/`).

```nix
models = {
  # URN shorthand → download mode, real file on the data disk
  "krea2TurboFP8_krea2TURBO.safetensors" = {
    urn = "urn:air:krea2:checkpoint:civitai:2723583@3060999+2939623";
    sha256 = "0kpn616i…";            # nix base32 (see hash step below)
  };
  "any-lora.safetensors" = "urn:air:krea2:lora:civitai:1234@5678+9012"; # plain string, no hash yet
  "wf.json" = { urn = "…"; type = "workflows"; sha256 = "…"; };         # workflow JSON → user/default/workflows/
};
```

- **URN**: `urn:air:<family>:<type>:civitai:<modelId>@<versionId>[+<fileId>]` → maps to
  `https://civitai.red/api/download/models/<versionId>?fileId=<fileId>` and a folder
  (`checkpoint→checkpoints`, `lora→loras`, `vae→vae`, `clip→clip`,
  `diffusion_model→diffusion_models`, …). `<type>` can be `Workflows`/`unknown` — that's a
  **JSON workflow, not a model**: set explicit `type = "workflows"`.
- **Modes**: `store` (default for explicit `url`+`sha256`) = pure build-time `pkgs.fetchurl`
  symlinked in; `download` (default for URN entries) = resumable curl into
  `<dataDir>/models/<type>/` at activation by `comfy-ui-prepare-dirs`, with a `.sha256`
  **marker** next to the file for fast no-op boots. `mode` overrides on the entry.
- **sha256 attr format**: nix base32 (52 chars, alphabet `0-9a-z` minus `e,o,u,t`). Shell
  `sha256sum` needs hex: `config.nix` has `sha256ToHex` (pure-Nix little-endian bit-string
  decoder — `builtins.convertHash` and big ints do NOT work in modern Nix).
- **Creator-gated files** (civitai `401 "requires you to be logged in"`): the download script
  sends `Authorization: Bearer $(cat <civitaiApiKeyPath>)` when that option is set; curl -L
  never forwards the header to the CDN host. A failed 401 aborts the oneshot loudly.
- **Civitai R2 drops mid-stream** on GB files: the models `fetchurl` passes
  `curlOptsList = [ "--retry" "20" "--retry-delay" "2" "--retry-all-errors" ]` (store mode)
  and download mode uses `curl -C - --retry-all-errors` (resumes).

### Workflow for adding a model (ground truth from ops)

1. Resolve the URN via the API (needs the agenix key):
   `curl -s https://civitai.com/api/v1/model-versions/<versionId> -H "Authorization: Bearer $(sudo -n cat /run/agenix/civitai-key)"` → note the **fileId's real filename** and `sizeKB`.
   A `type` of `Workflows`/`Config` means it's a JSON workflow, not a model.
2. Fetch + hash (resumable, then convert to nix32):
   ```
   cd <dataDir>/models/<type>
   curl -sSL -H "Authorization: Bearer $(sudo -n cat /run/agenix/civitai-key)" \
     --retry 1000 --retry-all-errors -C - -o <filename> \
     "https://civitai.red/api/download/models/<versionId>?fileId=<fileId>"
   nix hash convert --hash-algo sha256 --to nix32 "$(nix hash file <filename>)"
   ```
   (Do NOT depend on `nix-prefetch-url` — its 5-attempt cap dies on civitai R2.)
   Pre-placing the file makes the next activation verify-by-hash + write the marker instead
   of re-downloading.
3. Add the entry to `configurations/nixos/server/default.nix` (name = real filename).
4. `nix run nixpkgs#nixpkgs-fmt -- <edited files>`, then the eval gate:
   `nix eval '.#nixosConfigurations.server.config.system.build.toplevel.drvPath'` (pure —
   no `--impure`; a failed assertion prints a "Failed assertions" error listing the model
   problem: bad URN, unresolvable folder, store mode without hash, urn+url both set).
5. Activate: `nix run .#activate` from `~/nixos-config`. Watch
   `journalctl -u comfy-ui-prepare-dirs` for `models: linked/downloaded/replaced` lines.
6. Verify live: `curl -s http://127.0.0.1:8188/object_info/<LoaderClass>` (e.g.
   `CheckpointLoaderSimple`, `LoraLoader`) lists the filename.

## Gotchas learned the hard way (all in the code comments / README)

- **Disk space**: GB-scale `fetchurl` into the store + tight nvme → before big model builds,
  check `df -h /` and run `nix store gc` (the store can need 10+ GB). 12.9 GB models should
  use **download mode**, not store mode.
- **Manager is a python package, NOT a custom node**: `--enable-manager` silently disables
  if `comfyui_manager` isn't importable; it's built from a **release tag** (never `main` —
  main lags at 3.41 and fails the ≥4.2.1 frontend check) and injected via PYTHONPATH.
- **HOME must be exported** to `dataDir` in the unit script: the `comfy-ui` passwd home is
  `/var/empty` (read-only) and the civitai pack persists under `~/.civitai/`.
- **socketio** (`python-socketio` + `websocket-client`) is injected into PYTHONPATH when the
  `civitai-comfy-nodes` preset is on (link sharing needs it at runtime).
- **Proxy**: `extraLocations` for `/civitai/*` must stay **multi-line** Caddyfile (single-line
  `handle { }` is invalid); the pack fetches root-relative `/civitai/...` paths that would
  otherwise 404 behind the `/comfyui/` prefix.
- **nixpkgs-fmt + eval gate before any activate** — the repo requires pure activation.

## Conventions

Follow the repo's `AGENTS.md` (and this module's README) conventions: nixpkgs-fmt all nix
files, keep `tests.nix` assertions for any new validation, update `options.nix` docs +
`README.md` when options change, prefer `lib.mkDefault`/`mkIf` patterns like siblings.