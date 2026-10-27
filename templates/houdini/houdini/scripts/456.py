"""Backstop for the MCP bridge: also try on every scene load.

Houdini sources `123.py` once at startup and `456.py` after each scene is
loaded. If the startup hook is ever missed — a project copied without the
file, a different HOUDINI_PATH, a session that predates it — loading a .hip
still gets the bridge up, which is the difference between the MCP tools
working and not.

It does nothing of its own: it runs `123.py` by path, so there is one copy of
the logic to keep correct. Both are idempotent — whichever runs second finds
the port busy and declines, quietly.

Finding 123.py without __file__
--------------------------------
Houdini executes these files with `exec`, not as imported modules, so
`__file__` does not exist and `os.path.dirname(__file__)` raises NameError —
which is exactly what this file did on its first attempt, on every scene load.
The sibling is located through the mechanisms that *do* work here:

1. `hou.findFile`, which searches HOUDINI_PATH;
2. the same search by hand over `$HOUDINI_PATH`, which also covers the '&'
   placeholder Houdini expands internally;
3. `__file__` last, for the case where something does run it as a module.
"""

import os
import runpy

_NAME = "123.py"


def _candidates() -> list:
    """Paths that might hold the bridge script, best guess first."""
    found = []

    try:
        import hou

        resolved = hou.findFile(os.path.join("scripts", _NAME))
        if resolved:
            found.append(resolved)
    except ImportError:
        pass  # no hou: the hand-rolled search below covers it
    except Exception:  # noqa: BLE001, S110 - findFile is best-effort only
        pass

    raw = os.environ.get("HOUDINI_PATH", "")
    for entry in raw.split(os.pathsep):
        entry = entry.strip()
        if not entry or entry == "&":
            continue
        found.append(os.path.join(entry, "scripts", _NAME))
        found.append(os.path.join(entry, _NAME))

    try:
        found.append(os.path.join(os.path.dirname(os.path.abspath(__file__)), _NAME))
    except NameError:
        pass  # exec'd by Houdini: __file__ genuinely does not exist

    return found


def _bridge_path() -> str:
    for path in _candidates():
        if os.path.isfile(path):
            return path
    return ""


def main() -> None:
    path = _bridge_path()
    if not path:
        # Never raise out of a scene-load hook: a traceback here interrupts
        # loading for everyone, and the only cost of missing is that the
        # startup hook is the single thing keeping the bridge alive.
        print(f"[houdini] mcp bridge: could not find {_NAME} on HOUDINI_PATH "
              f"— not starting from 456.py")
        return
    runpy.run_path(path, run_name="houdini_mcp_bridge")


main()
