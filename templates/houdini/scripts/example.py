"""Example external script for the `python_from_file` Python SOP.

The node ships in `houdini/otls/python_from_file.hdanc`; because the flake puts
`./houdini` on `HOUDINI_PATH`, it appears in the Tab menu under **Digital Assets
> Python From File**. Point its **Script Path** parm at this file, press
**Cook Script**, and it runs on every cook.

The example deliberately touches every feature of the node:

  * ``PARM_SCHEMA`` — every supported parm type (folder, menu, dynamic menu,
    string, file, int, float, toggle, button), so the node's interface is built
    from this file rather than from hand-made parms.
  * ``INPUT_SCHEMA`` — two extra inputs, so ``main()`` is called with the 4th
    ``inputs`` argument and the node grows a "Use Input N" toggle per input.
  * ``main(node, geo, parms, inputs)`` — the 4-argument form. Delete ``inputs``
    (and ``INPUT_SCHEMA``) for the 3-argument form, or define ``run()`` instead.
  * geometry output, point attributes, a detail attribute, and a point group.

The script is loaded with importlib and cached by resolved path + mtime, so
editing this file and re-cooking picks up the changes without restarting
Houdini.

Path resolution
---------------
Set ``Script Path`` to the absolute path of this file, or to a path relative to
the current ``.hip`` (e.g. ``../scripts/example.py`` when the scene lives in
``hip/``). A bare ``example.py`` is also searched for in ``$HIP`` and
``$HIP/scripts``.
"""

from __future__ import annotations

import math
from typing import Any

import hou

# ── The node's parameter interface ──────────────────────────────────────────
#
# Every entry below becomes a real parm on the SOP the first time it cooks.
# Delete an entry and the parm is pruned on the next cook; edit a default and
# the node's interface follows. `folder` groups everything that follows it.
#
# Supported types: menu | string | file | int | float | toggle | button | folder
PARM_SCHEMA: dict[str, Any] = {
    "shape": {"type": "folder", "label": "Shape"},
    "mode": {
        "type": "menu",
        "label": "Mode",
        "items": {
            "grid": "Generate grid",
            "input": "Displace input 0",
        },
        "default": "grid",
    },
    # A dynamic menu re-reads this dict from the file when the dropdown opens,
    # instead of baking the options in at cook time.
    "palette": {
        "type": "menu",
        "label": "Palette",
        "items": {
            "warm": "Warm",
            "cool": "Cool",
            "mono": "Mono",
        },
        "default": "cool",
        "dynamic": True,
    },
    "rows": {"type": "int", "label": "Rows", "default": 12, "min": 3, "max": 64},
    "cols": {"type": "int", "label": "Columns", "default": 16, "min": 3, "max": 64},
    "amplitude": {
        "type": "float",
        "label": "Amplitude",
        "default": 0.35,
        "min": 0.0,
        "max": 2.0,
    },
    "group": {"type": "string", "label": "Point Group", "default": ""},
    "cachefile": {"type": "file", "label": "Cache File", "default": ""},
    "savecache": {
        "type": "button",
        "label": "Save Cache",
        "script_callback": (
            "import hou\n"
            "node = kwargs['node']\n"
            "path = str(node.parm('cachefile').eval()).strip()\n"
            "if path:\n"
            "    node.geometry().saveToFile(path)\n"
        ),
    },
    "verbose": {"type": "toggle", "label": "Verbose", "default": True},
    "rebuild": {
        "type": "button",
        "label": "Rebuild",
        "script_callback": "import hou; kwargs['node'].cook(force=True)",
    },
}

# Two extra inputs on a node with three connectors. The toggle names derive from
# these keys: "useinput_field" and "useinput_mask". Declared inputs default to
# ON; the mask is OFF so an unwired third input is quiet. A 4-argument main()
# receives them as `inputs`, index 0 being SOP input 1.
INPUT_SCHEMA: dict[str, Any] = {
    "field": {"label": "Field"},
    "mask": {"label": "Mask", "default": False},
}

_PALETTES: dict[str, tuple] = {
    "warm": ((1.0, 0.35, 0.10), (0.90, 0.05, 0.35)),
    "cool": ((0.10, 0.45, 1.00), (0.00, 0.90, 0.80)),
    "mono": ((0.85, 0.85, 0.85), (0.15, 0.15, 0.15)),
}


def _menu(node: hou.SopNode, name: str, default: str) -> str:
    """Read a menu parm as its token.

    `parms[name]` holds the menu *index* (the node evaluates every parm with
    `Parm.eval()`), so menus are read back from the parm instead. This is the
    one place where the `parms` dict is not enough on its own.
    """
    parm = node.parm(name)
    if parm is None:
        return default
    return parm.evalAsString() or default


def _extent(field: hou.Geometry | None) -> tuple:
    """Use the field input's footprint as the grid's size (2x2 by default)."""
    if field is None or len(field.points()) == 0:
        return 2.0, 2.0
    size = field.boundingBox().sizevec()
    return max(float(size[0]), 0.001), max(float(size[1]), 0.001)


def _mask_box(mask: hou.Geometry | None) -> hou.BoundingBox | None:
    """The mask input's bounding box: displacement only happens inside it."""
    if mask is None or len(mask.points()) == 0:
        return None
    return mask.boundingBox()


def _build_grid(
    geo: hou.Geometry, rows: int, cols: int, extent_x: float, extent_y: float
) -> None:
    """Create a rows x cols quad grid centred on the origin."""
    points: list[hou.Point] = []
    for row in range(rows):
        for col in range(cols):
            u = col / max(cols - 1, 1)
            v = row / max(rows - 1, 1)
            point = geo.createPoint()
            point.setPosition(((u - 0.5) * extent_x, (v - 0.5) * extent_y, 0.0))
            points.append(point)

    for row in range(rows - 1):
        for col in range(cols - 1):
            poly = geo.createPolygon()
            poly.addVertex(points[row * cols + col])
            poly.addVertex(points[row * cols + col + 1])
            poly.addVertex(points[(row + 1) * cols + col + 1])
            poly.addVertex(points[(row + 1) * cols + col])


def _displace(
    geo: hou.Geometry,
    amplitude: float,
    extent_x: float,
    extent_y: float,
    mask: hou.BoundingBox | None,
    palette: str,
) -> None:
    """Displace along Z and write the point attributes / colours."""
    if geo.findPointAttrib("py_sop") is None:
        geo.addAttrib(hou.attribType.Point, "py_sop", 0.0)
    if geo.findPointAttrib("Cd") is None:
        geo.addAttrib(hou.attribType.Point, "Cd", (0.0, 0.0, 0.0))

    low, high = _PALETTES.get(palette, _PALETTES["cool"])
    for point in geo.points():
        pos = point.position()
        u = pos[0] / extent_x + 0.5
        v = pos[1] / extent_y + 0.5
        wave = math.sin(u * math.tau) * math.cos(v * math.tau)

        if mask is not None and not mask.contains((pos[0], pos[1], pos[2])):
            wave = 0.0

        point.setPosition([pos[0], pos[1], pos[2] + amplitude * wave])
        point.setAttribValue("py_sop", wave)

        t = 0.5 + 0.5 * wave
        point.setAttribValue(
            "Cd",
            (
                low[0] + (high[0] - low[0]) * t,
                low[1] + (high[1] - low[1]) * t,
                low[2] + (high[2] - low[2]) * t,
            ),
        )


def main(
    node: hou.SopNode,
    geo: hou.Geometry | None,
    parms: dict[str, Any],
    inputs: list[hou.Geometry | None],
) -> None:
    """Called by the Python SOP on every cook (4-argument form).

    ``inputs`` is the list of declared extra inputs: index 0 is SOP input 1
    (``field``), index 1 is input 2 (``mask``). An entry is ``None`` when its
    toggle is off or nothing is connected.
    """
    if geo is None:
        return

    mode = _menu(node, "mode", "grid")
    rows = max(3, min(64, int(parms.get("rows", 12))))
    cols = max(3, min(64, int(parms.get("cols", 16))))
    amplitude = max(0.0, float(parms.get("amplitude", 0.35)))
    palette = _menu(node, "palette", "cool")
    verbose = bool(parms.get("verbose", True))

    field = inputs[0] if len(inputs) > 0 else None
    mask = inputs[1] if len(inputs) > 1 else None
    extent_x, extent_y = _extent(field)
    mask_box = _mask_box(mask)

    # A Python SOP's output geometry survives between cooks, so start clean.
    geo.clear()

    if mode == "input":
        upstream = node.inputGeometry(0)
        if upstream is None:
            if verbose:
                print("[example] no input 0 — building a grid instead")
            _build_grid(geo, rows, cols, extent_x, extent_y)
        else:
            geo.merge(upstream)
    else:
        _build_grid(geo, rows, cols, extent_x, extent_y)

    _displace(geo, amplitude, extent_x, extent_y, mask_box, palette)

    group_name = str(parms.get("group", "")).strip()
    if group_name:
        geo.createPointGroup(group_name).add(list(geo.points()))

    if geo.findGlobalAttrib("python_sop") is None:
        geo.addAttrib(hou.attribType.Global, "python_sop", "")
    geo.setGlobalAttribValue(
        "python_sop",
        f"mode={mode} rows={rows} cols={cols} "
        f"field={'yes' if field is not None else 'no'} "
        f"mask={'yes' if mask is not None else 'no'}",
    )

    if verbose:
        print(
            f"[example] {node.path()}: {mode} -> "
            f"{len(geo.points())} points / {len(geo.prims())} prims "
            f"(field={'yes' if field is not None else 'no'}, "
            f"mask={'yes' if mask is not None else 'no'})"
        )
        cache = str(parms.get("cachefile", "")).strip()
        if cache:
            print(f"[example] Cache File is set to {cache!r}")


# Alternative entry point: delete main() above and define run() instead. It gets
# no arguments, so pull the node and geometry yourself:
#
#     def run() -> None:
#         node = hou.pwd()
#         geo = node.geometry()
#         ...


if __name__ == "__main__":
    print(
        "This is a node script, not a standalone one.\n"
        "Create a 'Python From File' SOP and set its Script Path to this file.\n"
        "For a standalone hython tour, run scripts/hython_tour.py instead."
    )
