# Houdini hscript

> Skill for reading, writing, and migrating Houdini's legacy scripting
> language, **hscript**, and hscript expressions. Pure language knowledge;
> usable without Houdini. `hscript` ships with Houdini (also in the nixpkgs
> FHS wrapper) for running scripts from the command line.

## When to use

- A user has an old shelf tool, `.cmd` script, or an HDA/OTL with hscript
  callbacks and needs to understand or convert it.
- You are reviewing expressions like `$F`, `$T`, `$HIP`, `opparm ...`.
- You need to decide whether to use hscript vs `hou` Python vs VEX.

## Key facts

- **hscript was Houdini's original scripting language** (a C-shell-like
  command language) used for shelf tools, the command line, and old HDAs /
  expressions. Modern Houdini defaults to Python, but hscript survives in:
  - shelf tool scripts saved as `hscript ...` in old `.shelf` files,
  - old HDAs' callbacks (button / `script` parm callbacks),
  - HScript **expressions** in parameter fields (`$F`, `$T`, `$HIP`, ...).
- **Running**: `hscript` (interactive), `hscript -c "command"` / `hscript <
  script.cmd` from the shell. In a session, the Houdini Command Editor is
  hscript by default; Python scripts are passed through `python`/`py`.
- Core commands (non-exhaustive):
  - `opparm node parm value` — set a parameter (`opparm /obj/geo1 tx 5`)
  - `opparm node -l` — list parameters/values
  - `run <cmd>` — run an hscript command string
  - `source <file>` — source a script file
  - `ls`, `cd`, `echo`, `set`, `get`, `help <cmd>`, `ex`/`opexpr` (expression
    helpers), `cf` (copy files)
  - `if/while/foreach` control flow, `$var` variables, backticks
    `` `command` `` for command substitution
- **Expressions vs VEX vs hscript**:
  - hscript expression (`$F` = current frame, `$T` = time in seconds,
    `$FSTART`/`$FEND` frame range, `$HIP` = hip file directory, `$JOB` = job
    dir, `$OS` = current operator path) — used in parameter fields, evaluated
    per-cook.
  - VEX — C-like processing language inside wrangles/VOPs.
  - HOM Python — modern automation of the whole scene.

## Sample hscript

```bash
# Set a value
opparm /obj/geo1 tx 5
# List parms
opparm /obj/geo1 -l
# Expression in a parm: $F / 24 → seconds-ish
# Conditionals
if (`get /obj/geo1 tx` > 3) {
    echo "big"
} else {
    echo "small"
}
# Convert to python? Use HOM instead:
# python: hou.node("/obj/geo1").parm("tx").set(5)
```

## Migration: hscript → Python

| hscript | HOM Python |
|---------|-----------|
| `opparm node parm val` | `hou.node("node").parm("parm").set(val)` |
| `opparm node -l` | `[p.name() for p in hou.node("node").parms()]` |
| `$F` | `hou.frame()` |
| `$T` | `hou.time()` |
| `$HIP` | `hou.hipFile.path()` (dir) |
| `run cmd` | rewrite as HOM calls |

Prefer HOM Python for anything new; only keep hscript for legacy compat.

## Gotchas

- **hscript is case-sensitive** and its quoting rules differ from bash
  (single/double quotes are literal-ish; backticks execute).
- Expressions evaluated per-cook: using I/O in expressions is discouraged;
  side effects belong in scripts/HDAs.
- Old HDAs may mix hscript + Python callbacks — the expression/script mode is
  set per template field; Python HDAs use `kwargs` instead of `$`-variables.
- `$F` vs VEX `@Frame`: the same value, different syntax — mixing them in one
  file is a version-flag of legacy code.

## References

- hscript command reference: https://www.sidefx.com/docs/houdini/commands/index.html
- Expression functions: https://www.sidefx.com/docs/houdini/expressions/index.html
- `hscript` binary: shipped with Houdini (`hscript -h` is authoritative)