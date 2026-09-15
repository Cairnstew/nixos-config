# Houdini HDAs & .otl

> Skill for understanding, building, and editing Houdini Digital Assets (HDAs)
> and OTL libraries. Includes the `hotl` command-line tool. Works without
> Houdini installed for reading/inspecting HDA archives; building/installing
> needs a Houdini session or `hotl`.

## When to use

- A user shares an `.hda`/`.otl` and you need to know what's inside.
- You are reviewing or generating HDA build scripts (`hou.hda` calls), shelf
  tools' digital assets, or `hotl` invocations.
- You need to fix an HDA's embedded Python callback or parameter interface.

## Key facts

- **HDA = Houdini Digital Asset** — a node type bundle: the node network it
  wraps, its parameter interface (UI), embedded scripts, help, and icons.
  Saved as a `.hda` file (single asset) or `.otl` (library of assets).
- **An HDA/OTL file is a zip archive.** `unzip -l file.hda` shows the layout:
  - `....hip` — the wrapped network (the asset's "inside")
  - `Sections/` — OTL section binaries (type definitions, parm templates)
  - `Scripts/` — embedded Python modules (`python2.7libs`/`python3.Xlibs`
    folders, `scripts` — these ship with the asset)
  - `help/` — `_index.html` + per-tool help pages
  - `otl_*` TOC files / `houdini.env` markers
- Inspecting without Houdini: `unzip -l`, `unzip -p file.hda '<asset>.hip'`
  (the network section is the readable part; parameter values live in the
  binary Sections), and `strings` for embedded script names. Full semantics
  (parm UI, python callback execution) need Houdini/`hython`.
- **`hotl`** — Houdini's built-in HDA/OTL command-line utility (shipped with
  Houdini, also exposed by the nixpkgs `houdini` FHS wrapper). Listed in
  `bin/hotl`. Run `hotl -h` for its exact subcommands; typical jobs: append
  assets into an OTL, list/update/remove asset definitions, and dump version
  info. It is the scriptable way to manage `.otl`/`.hda` libraries outside a
  GUI session.

## Building an HDA

- **GUI path**: build the node network → right-click node → *Save as Digital
  Asset…* (defines the type name, save location, and UI). This writes the
  `.hda` and can install it.
- **Python path** (Houdini Python, in-session):
  ```python
  import hou
  node = hou.node("/obj/geo1")                    # the wrapped network
  # Save as digital asset (Houdini UI helper)
  hou.hda.saveDigitalAsset(node, "/tmp/myasset.hda", ...)
  # Install for the session
  hou.hda.installFile("/tmp/myasset.hda")
  # Inspect definitions
  defs = hou.hda.definitionsInFile("/tmp/myasset.hda")
  for d in defs:
      print(d.nodeTypeName(), d.nodeTypeCategory())
  ```
  Exact signatures vary by release — check the HOM `hou.hda` docs.
- **Parms / UI**: the parameter interface is a *parameter template* with
  folders, float/vector/string/ramp/menu parms and optional expressions.
  Embedded Python callbacks (button scripts, `callback` parm scripts) run in
  Houdini's Python (via `kwargs`) or hscript, depending on the template.

## Gotchas

- `.otl` vs `.hda`: `.otl` holds one or more asset definitions in a library;
  `.hda` is the extension for a single digital asset file, but both are the
  same zip-based OTL archive format — don't rely on the extension alone.
- **Version locking**: an HDA is tied to the Houdini version that saved it;
  newer releases may refuse an old `.otl`/upgrade it on first load.
- **Never hand-edit the binary `Sections/`** — regenerate via `hotl` or the
  UI. Editing the `.hip` section by hand is possible but invalidates the
  embedded type metadata.
- Embedded Python: assets can carry `python2.7libs` (old) vs `python3.Xlibs` —
  check which your Houdini release loads and don't mix.
- Paths inside HDAs usually resolve relative to `$HIP`/`$JOB` — keep files
  alongside the `.hda` or use `$HIP`-anchored references.

## References

- HDA docs: https://www.sidefx.com/docs/houdini/hda/index.html
- `hotl` reference: part of the Houdini installation; `hotl -h` is
  authoritative (`bin/hotl`, also in the nixpkgs wrapper).
- HOM `hou.hda`: https://www.sidefx.com/docs/houdini/hom/hou/hda/