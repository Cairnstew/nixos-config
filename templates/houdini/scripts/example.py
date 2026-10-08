"""Example standalone hython script.

Run through the project flake:

    nix run .#hython -- scripts/example.py

or from inside `nix develop`:

    hython scripts/example.py

`hou` is only importable inside Houdini's interpreter (hython), which is why
these scripts are not run with the plain `python3` on PATH.
"""

import hou


def main() -> None:
    hip = hou.hipFile.name() or "<unsaved>"
    root = hou.node("/obj")
    print(f"Houdini {hou.applicationVersionString()}")
    print(f"  HIP: {hip}")
    print(f"  /obj children: {[c.name() for c in root.children()]}")


if __name__ == "__main__":
    main()
