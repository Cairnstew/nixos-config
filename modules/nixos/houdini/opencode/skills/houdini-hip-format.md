# Houdini .hip File Format

> Skill for working with Houdini scene files (`.hip`, `.hipnc`, `.hiplc`,
> `.hipsc`) on disk — what the format is, what can be inspected without
> Houdini, and the honest boundaries. Reading/parsing works with any tools;
> loading/saving scene semantics require Houdini (`hython`).

## When to use

- A user gives you a `.hip` file and asks what's in it.
- You need to extract node names, parameter values, or reference paths from a
  scene without launching (or having) Houdini.
- You are about to write tooling that reads/edits `.hip` files.

## Key facts

- **`.hip` is a proprietary binary format** — NOT a zip (unlike `.hda`/`.otl`
  archives) and not text. It is versioned per Houdini release and usually
  compressed (zlib-style). Structure: a header (magic + version), then
  serialized node network data, parameter values, and (optionally) embedded
  geometry/cache streams.
- **Variants are license markers, not formats**: `.hip` (commercial),
  `.hipnc` (non-commercial), `.hiplc` (learning), `.hipsc` (student). The
  binary layout is the same; the license class limits what you can do with
  it (e.g. `.hiplc` files won't open in commercial Houdini).
- **What you CAN get without Houdini** (honest limits):
  - `strings file.hip` — ASCII/UTF-8 passages: node names, parameter names,
    string parameter values, file references, shader/node type names.
  - `file file.hip` — confirms the format (`data` or zlib).
  - `grep -ao 'someNodeType' file.hip` — find occurrences of a type/name.
  - These are best-effort: values are typed and often length-prefixed or
    numeric, so any extraction is heuristic, not schema-driven.
- **What you CANNOT do without Houdini**: reliably decode parameter values
  (types/layout vary by version), resolve the connection graph, evaluate
  expressions, or round-trip an edited file. **Never hand-edit a `.hip`** —
  checksums and version fields make edits silently corrupt or un-loadable.
- **With Houdini available**, use `hython`:
  ```bash
  hython -c "import hou; hou.hipFile.load('/path/foo.hip'); print([n.path() for n in hou.node('/').allSubChildren()])"
  ```
  or a script that loads, walks `hou.node("/")`, reads parms, and saves.

## Reference extraction recipe (no Houdini)

```bash
# Which node types / relative paths are referenced?
strings scene.hip | grep -oE '/(obj|shop|out|vex|stage|ch)[A-Za-z0-9_./]*' | sort -u
# Find a specific node type usage
grep -ao 'geo[A-Za-z0-9_]*' scene.hip | sort | uniq -c | sort -rn
# Parameter names present (meet the HOM aliases)
strings scene.hip | grep -aoE '"(tx|ty|tz|scale|Cd|P|name)":?' | sort -u
```

Always caveat: results are **incomplete and heuristic**; confirm with `hython`
when Houdini exists.

## Gotchas

- Version mismatch: a `.hip` from a NEWER Houdini than installed will not
  load (or will load degraded) — check the header info (e.g. via `hython`;
  or see the "Created by"  string with `strings`).
- Big `.hip` files may embed cached geometry (`.bgeo` blobs) — `strings` on
  those regions yields binary noise; skip ranges that look compressed.
- `.hiplc`/`.hipnc` files from Apprentice are the usual free-license exchange
  format — don't assume they contain data your license class forbids.
- Differential reading: only text-visible attributes (names, string parm
  values, file paths, node type names) survive `strings`-style parsing.

## References

- Scene files overview: https://www.sidefx.com/docs/houdini/ref/hip.html
- HOM hipFile: https://www.sidefx.com/docs/houdini/hom/hou/hipFile.html
- hython: https://www.sidefx.com/docs/houdini/hom/locations.html