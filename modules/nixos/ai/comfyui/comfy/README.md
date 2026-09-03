# Repo-local ComfyUI v0.29.2 package

The `stable-diffusion-webui-nix` flake input's `main` still pins ComfyUI
**v0.25.1**, which has **no native Krea 2 support** (no `comfy/ldm/krea2/`, no
`comfy/text_encoders/krea2.py`, and `CLIPLoader` has no `"krea2"` type). This
directory vendors a **v0.29.2** build (newest stable of the 0.29.x line —
community deploy notes point there for the best FP8 behavior; native Krea 2
landed in v0.26.0) so the module can run Krea 2 without forking the input.

Files:

- `dist.nix` — the distribution definition (fork of the input's
  `source/comfy/default.nix`): source pin `v0.29.2` + the same
  `additionalRequirements` + `createPackage` wiring.
- `install-instructions-cuda.json` — the **regenerated** flexseal requirements
  lock for v0.29.2 (unless you bump the source pin, keep this in sync).
- `package.nix` — the runtime wrapper (copy of the input's
  `source/comfy/package.nix`): `exec python main.py` with the flexseal python
  env and CUDA libs.
- `default.nix` — the package builder. It feeds `webuiPkgs` into the input's
  OWN `requirements/` machinery (`${stable-diffusion-webui-nix}/requirements`),
  so the python env, CUDA fixups and env assembly are all upstream-tested code.
  It also applies a small *extra* fixup overlay (`extraFixups`) on top of the
  input's `package-fixups.nix` for wheels that are newer than the input's lock
  (bitsandbytes ≥ 0.50 ROCm/XPU loader stubs need extra auto-patchelf ignores).

## Upgrading ComfyUI

1. Pick the new tag (verify against the upstream release list, e.g.
   `https://api.github.com/repos/Comfy-Org/ComfyUI/releases`).
2. Get the fetch hash: `nix run nixpkgs#nix-prefetch-github -- --rev <tag> comfy-org ComfyUI`.
3. Update `rev` + `hash` in `dist.nix`.
4. **Regenerate the requirements lock** — do NOT reuse the old one (the source's
   requirements.txt changed: frontend package, comfy-kitchen, comfy-angle, …):
   - Copy the pinned-input source to a scratch dir and bump the rev there:
     `cp -r <input-outPath> /tmp/sdwn-work` (get outPath with
     `nix eval --impure --raw --expr 'let f = builtins.getFlake "path:/path/to/nixos-config"; in f.inputs.stable-diffusion-webui-nix.outPath'`).
   - `git init` + commit inside the scratch dir, then run the update helper:
     `nix run .#stable-diffusion-webui.comfy.cuda.update-helper -- source/comfy/install-instructions-cuda.json`
     (requires network; pip dry-run + flexseal seal, ~30-60s).
   - Copy the regenerated JSON over `./install-instructions-cuda.json`.
5. `nix build '.#nixosConfigurations.server.config.services.comfyUi.package'`
   and verify the krea2 modules ship:
   - find the ComfyUI source store path from the built wrapper
     (`grep -o '/nix/store/[a-z0-9]*-ComfyUI' $P/bin/comfy-ui`), then
     `ls $P/comfy/ldm/krea2/` and `ls $P/comfy/text_encoders/krea2.py`.

See the module README for how to run it (service + models).