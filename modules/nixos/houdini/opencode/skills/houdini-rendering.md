# Houdini Command-Line Rendering

> Skill for rendering Houdini scenes headlessly from the command line with
> `husk` (Karma), `mantra`, and `hrender`, and for building render scripts
> with `hython`. The commands ship with Houdini (and in the nixpkgs `houdini`
> FHS wrapper); a license seat is required even headless.

## When to use

- A user wants to render a `.hip` scene without opening the GUI.
- You are writing a pipeline script/CI step that renders frames via husk,
  mantra, or hrender, or builds/re-cooks scenes with hython first.
- You need to set up render output drivers (ROP nodes) for headless use.

## Key facts

- **Three CLI renderers, three eras:**
  - `husk` — the Hydra renderer launcher, drives **Karma** (Solaris/Hydra).
    Modern; renders USD/Hydra scene graphs and can render hip-based stages.
  - `mantra` — the legacy production renderer CLI (Mantra). Older, still
    used for compatibility; Maya/Mantra heritage.
  - `hrender` — renders an existing ROP (render output driver) node from a
    hip file: `hrender scene.hip ropname`. Works with Mantra, Karma,
    Solaris, and most ROP family nodes. Check `hrender -h`.
- **Typical headless flow**: build/load the scene with `hython` (create ROP,
  set output path), then invoke the renderer; or pass the scene file
  directly:
  ```bash
  hython script.py                       # build/cook scene, e.g. create Karma ROP
  husk scene.hip -o /out/frame.exr -F 1-10   # render frames 1-10 (husk flags: see husk -h)
  mantra -f scene.hip /out/frame.exr          # equivalent legacy path
  hrender scene.hip karma1                   # render via ROP node
  ```
  Exact flags vary by version — always `husk -h` / `mantra -h` /
  `hrender -h` first.

## Patterns

```python
# hython: programmatic render setup (HOM)
import hou
hou.hipFile.load("/proj/shot.hip")
rop = hou.node("/out/karma1")
rop.parm("camera").set("/obj/cam1")
rop.parm("vm_picture").set("/out/frame.exr")   # output filename parm
rop.parm("f1").set(1); rop.parm("f2").set(10)  # frame range
rop.render()                                    # render the ROP
hou.hipFile.save("/proj/rendered.hip")
```

## Gotchas

- **License**: hython/husk/mantra all need a Houdini license seat. Apprentice
  (free, non-commercial) licenses these headless tools for learning/personal
  use; commercial license required for paid work.
- **Frames/output**: don't guess flag names — `-F` frame selection, `-o`
  output file, `-t`/`-T` (time range) vary between versions and renderers.
  `husk -h` is the contract.
- **Karma vs Mantra**: Karma (husk) is USD-native and GPU/CPU; Mantra is
  legacy. A scene's ROPs decide — matching ROP type to CLI matters.
- **Environment**: headless renderers may need `HOUDINI_PATH`/`JOB` set for
  file references (`$JOB`/`$HIP`-anchored paths break when run from a
  different cwd). Set them explicitly in scripts.
- **Red Giant / OFX crash**: some versions crash launching with OpenFX
  plugins; the community workaround is
  `HOUDINI_DISABLE_OPENFX_DEFAULT_PATH=1` (affects 20.5.487+; keep it handy
  in CI scripts).
- In the nixpkgs wrapper, binaries appear as `houdini/bin/husk` etc. — your
  script's PATH must include the wrapper env (or the store paths).

## References

- Karma renderer: https://www.sidefx.com/docs/houdini/solaris/karmaguide.html
- husk launcher: https://www.sidefx.com/docs/houdini/husksubinj-pdg.htm
- Mantra CLI: `mantra -h` (shipped with Houdini)
- hrender: `hrender -h` (shipped with Houdini)