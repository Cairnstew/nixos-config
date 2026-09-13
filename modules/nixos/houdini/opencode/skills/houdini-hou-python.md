# Houdini HOM: hou Python module & hython

> Skill for writing and reviewing Houdini automation with the `hou` Python
> module (HOM) and `hython`, Houdini's headless Python interpreter. Works even
> when Houdini is NOT installed (API knowledge, file-format facts, and review
> patterns); a live Houdini is only needed to run scripts. When a Houdini MCP
> bridge is configured (`my.services.houdini.opencode.mcp`, e.g.
> `fxhoudinimcp`), prefer its tools for live sessions.

## When to use

- A user asks how to script Houdini (node creation, parameter edits, geometry
  reads, hip file load/save) in Python.
- You are reviewing a `.py` script that imports `hou` (HOM) or a `hython`-run
  script/command.
- You need to know which API call to use (parms, nodes, geometry, HDAs, hip
  files) without guessing.

## Key facts

- **HOM = Houdini Object Model**: the `hou` module is Houdini's Python API. It
  is only importable from a Houdini-bundled Python (the GUI's Python shell, a
  shelf tool, or `hython`) — not from a system Python.
- **`hython`** = Houdini's headless Python CLI, bundled with Houdini. Runs
  full HOM scripts with no GUI: `hython script.py`, `hython file.hip`
  (loads a hip then drops into interactive mode), `hython -c "print(hou.version())"`.
  Needs a Houdini license seat even headless (Apprentice non-commercial works).
- **Houdini's Python version is fixed per release** (e.g. H20.5 ships 3.9,
  H22 ships 3.11+). Code must be compatible with the bundled version, not
  whatever the host system has.

## Core API patterns

```python
import hou

# Node access
root = hou.node("/obj")               # absolute path
geo = root.createNode("geo")          # create node
box = geo.createNode("box")           # nested node
sop = hou.node("/obj/geo1/box1")      # direct access
node.inputs()                         # upstream nodes
node.outputs()                        # downstream nodes
node.children()                       # sub-nodes
node.moveToGoodPosition()             # auto-layout children

# Parameters
parm = node.parm("tx")                # single parm
parm.eval()                           # current value (float)
parm.set(1.5)                         # set value
node.setParms({ "tx": 1.5, "ty": 2.0 })  # batch set (parm name → value)
node.parmTuple("t").eval()            # vector parm (hou.Vector3)
node.parm("scale").evalAsFloat()

# Connections
node.setInput(0, upstream_node)       # wire input 0
node.setNextInput(upstream_node)      # append input
node.bypass(True)                     # toggle bypass
node.isBypassed()

# Cooking / evaluation
node.cook()                           # force cook
geo = node.geometry()                 # cooked geometry (hou.Geometry)

# Geometry (hou.Geometry)
points = geo.points()                 # all points (non-indexed copy if modified)
for pt in points:
    pos = pt.position()               # hou.Vector3
    pt.setPosition(pos + hou.Vector3(0, 1, 0))
prims = geo.prims()
for prim in prims:
    verts = prim.vertices()
    for v in verts:
        v.point()
# Attributes
geo.attribValue("Cd")                 # global attribute
geo.findGlobalAttrib("name")
pt.attribValue("P")                   # per-point
geo.appendAttrib("f@mydata", hou.attribType.Float)  # create float attrib
geo.addAttrib(hou.attribType.Point, "mydata", 0.0)

# Hip files
hou.hipFile.load("/path/to/file.hip")
hou.hipFile.save("/path/to/out.hip")
hou.hipFile.clear()
hou.hipFile.path()

# Undo grouping (batch ops into one undo)
with hou.undos.group("build network"):
    node = root.createNode("geo")
    node.parm("ty").set(3)

# Session / frame
hou.frame()                           # current frame (float)
hou.time()                            # current time in seconds
hou.setFrame(1)

# ROP render from python
rop = hou.node("/out/mantra1")
rop.render()
```

## Gotchas

- **HOM is not thread-safe** and many calls must run on Houdini's main thread.
  From a background thread use `hdefereval.executeInMainThread()` /
  `executeInMainThreadWithResult()` (this is also how MCP bridges stay safe).
- `node.geometry()` on a node inside a subnet may fail until the node cooks;
  call `node.cook()` first (or use `hou.node(...).geometry()` for SOPs).
- `parm.eval()` on un-cooked or time-dependent parms returns the value at the
  current frame; use `parm.evalAtFrame(frame)` / `evalAsString()` when needed.
- HDA-embedded Python callbacks receive a `kwargs` dict (`node`, `parm`,
  `script_value`, ...) — don't assume bare globals.
- Writing geometry: `geo.points()` returns a **snapshot** if the geometry has
  changed since the last cook; use `geo.iterPoints()` (lazy) when you don't
  need to mutate.

## References

- HOM overview: https://www.sidefx.com/docs/houdini/hom/
- `hou` module reference: https://www.sidefx.com/docs/houdini/hom/hou/
- hython: https://www.sidefx.com/docs/houdini/hom/locations.html (see
  "hython" section)
- SideFX docs on Houdini's bundled Python version per release.