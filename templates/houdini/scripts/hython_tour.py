"""Example standalone hython script.

Run through the project flake:

    nix run .#hython -- scripts/hython_tour.py

or from inside `nix develop`:

    hython scripts/hython_tour.py

`hou` is only importable inside Houdini's interpreter (hython), which is why
these scripts are not run with the plain `python3` on PATH.

Type-check with `nix run .#basedpyright` (or `nix run .#pyright`), which
resolves `hou` against the `types-houdini` stubs plus Houdini's own module
sources via `.stubs`, `.hou-libs` and `.hou-site` (see pyrightconfig.json).

## Reading this file as a typing tutorial

`hou` is typed, but four things in its API look surprising until you know
about them. All are demonstrated below:

1. **`hou.pwd()` and `hou.node()` return `hou.Node`, not a node *type*.**
   Since Houdini 20 `hou.Node` is an abstraction the network editor shares
   with APEX nodes, and most node-specific methods (`parm`, `geometry`, ...)
   moved to `hou.OpNode`. So `hou.pwd()` alone will not give you
   `.geometry()`, even though every node has one at runtime.

   Narrow it with `typing.cast()` when you know what the node is:

       node = cast(hou.SopNode, hou.pwd())
       node.geometry()      # -> Geometry | None

   (A plain annotation `node: hou.SopNode = hou.pwd()` is *rejected* — it is
   a downcast, and the type-checker is right that it is unproven.)

2. **`hou.node()` returns `Optional[hou.Node]`** because the path may not
   exist, so it needs a `None` check before you can use the result.

3. **`hou.OpNode.parm()` returns `Optional[hou.Parm]`** — a parm can be
   missing or hidden. Handle it rather than chaining `.set()` straight off.

4. **`Point.setPosition` is typed `Sequence[float]`**, and `hou.Vector3` only
   declares `__len__`/`__getitem__` (no `__iter__`), so it is not structurally
   a sequence to the type-checker — even though Houdini accepts one at
   runtime. See `move_points_up` for the workaround.
"""

from typing import cast

import hou


def required_parm(node: hou.OpNode, path: str) -> hou.Parm:
    """`node.parm(path)`, asserting the parm actually exists.

    `hu.OpNode.parm()` returns `Optional[Parm]`; wrapping it in a helper
    keeps the call site clean and still fails loudly if the parm is absent.
    """
    parm: hou.Parm | None = node.parm(path)
    if parm is None:
        raise RuntimeError(f"no parm {path!r} on {node.path()}")
    return parm


def hip_name() -> str:
    # The `types-houdini` stubs declare `hou.hipFile` as an *instance* of
    # `hipFile`, so this type-checks as `str` with no suppression. (Against
    # the raw SWIG `hou.py` this used to need a `reportCallIssue` ignore.)
    return hou.hipFile.name() or "<unsaved>"


def main() -> None:
    print(f"Houdini {hou.applicationVersionString()}")
    print(f"  HIP: {hip_name()}")

    # `hou.node()` returns `Optional[Node]` — check it, then narrow. Once the
    # target is known to be an object-level container, `cast` gives it the
    # methods `hou.Node` no longer carries.
    obj = hou.node("/obj")
    if obj is None:
        raise RuntimeError("expected /obj to exist")
    root = cast(hou.ObjNode, obj)

    children = root.children()  # -> Tuple[OpNode, ...]
    print(f"  /obj children: {[c.name() for c in children]}")

    # `createNode` returns `OpNode`, which carries `parm`, but the geometry
    # accessors live on `hou.SopNode` — and this is a SOP, so narrow it.
    container = root.createNode("geo", "sphere")
    sphere = cast(hou.SopNode, container.createNode("sphere", "sphere1"))
    required_parm(sphere, "type").set(1)  # 1 = polygon sphere
    for axis in ("radx", "rady", "radz"):
        required_parm(sphere, axis).set(1.0)
    container.layoutChildren()

    print(f"  created {container.path()}/{sphere.name()}")
    print(f"  radius: {required_parm(sphere, 'radx').eval()}")
    prims = sphere.geometry()
    print(f"  prims: {len(prims.prims()) if prims is not None else 0}")


def move_points_up() -> None:
    """The shape of a Python SOP / wrangle body.

    `hou` is already imported inside Houdini, so this function deliberately
    does not import it — the `.stubs/__builtins__.pyi` shipped by the flake
    teaches the type-checker that, and it still type-checks.
    """
    node = cast(hou.SopNode, hou.pwd())

    geo = node.geometry()
    if geo is None:
        return

    # Add code to modify contents of geo.
    for point in geo.points():
        pos = point.position()
        pos += hou.Vector3(0, 1, 0)
        # `hou.Vector3` is a runtime sequence of 3 floats, but the stubs give
        # it no `__iter__`, so the type-checker will not accept it where
        # `setPosition` asks for `Sequence[float]`. Pass the components — same
        # result at runtime, no suppression needed.
        point.setPosition([pos[0], pos[1], pos[2]])


if __name__ == "__main__":
    main()
