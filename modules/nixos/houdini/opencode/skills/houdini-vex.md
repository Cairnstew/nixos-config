# Houdini VEX

> Skill for writing and reviewing VEX code: attribute wrangles, VEXpressions,
> and VOP context programs. Pure language/file knowledge — usable without
> Houdini installed (the reference is static and reviewable). A live Houdini is
> only needed to compile/run.

## When to use

- A user asks for a wrangle snippet (noise, scatter, groups, attribute math).
- You are reviewing VEX code in a `.vfl`/wrangle/`@`-attribute context and need
  to verify syntax or semantics.
- You need to explain the difference between VEX contexts and HScript
  expressions (or Python).

## Key facts

- **VEX is a compiled, C-like shading/processing language** — not Python, not
  hscript. Typed, fast, automatically multithreaded inside wrangles.
- **Attribute syntax** is the core: `@name` reads/writes an attribute of the
  current element; the type prefix is the declaration:
  - `@P` → `vector` position (implicit, always exists)
  - `@Cd` → `vector` color
  - `@v` → `vector` velocity
  - `f@scale` → `float` attribute named `scale`
  - `i@id` → `int`
  - `v@vec` → `vector`
  - `s@name` → `string`
  - `u@foo` → `vector4`; `p@foo` → `matrix3`? (use `3@`/`4@` for matrices: `3@m3`, `4@m4`)
- **Wrangle modes** (`Attribute Wrangle` SOP): Point / Vertex / Primitive /
  Detail — the code runs per element of that type; Detail runs once.
- **Local variables** (in VEXpressions and some contexts): `P`, `N`, `ptnum`,
  `primnum`, `vtxnum`, `dopnum`, `Frame`, `Time`, `$F`-style hscript is NOT
  VEX — VEX uses `@Frame`, `@Time` (global attributes) instead.

## Common recipes

```vex
// Displace along normal
@P += normalize(@N) * 0.1 * noise(@P * 2.0);

// Fit an attribute to a range
float t = fit(@Cd.r, 0, 1, 0.2, 0.8);
@Cd = set(t, t, t);

// Scatter-like count per point stored in attribute
@pscale = fit01(rand(@ptnum + 123), 0.1, 1.0);

// Group by bounding box using if
if (@P.y > 2.0) @group_top = 1;   // implicit group attribute

// Use a ramp parameter from a wrangle parm
float r = chramp("ramp", fit01(sin(@Time), 0, 1));

// Vector math
@v = normalize(@P - set(0, 0, 0));
float d = length(@P);
@Cd = set(1, 0, 0) * clamp(d / 10.0, 0, 1);
```

## Gotchas

- `@P` is `vector`; use `.x/.y/.z` or `set()`. Don't compare vectors with `==`
  blindly; use `length()`.
- Attribute names with type prefixes are **case-sensitive** and must be valid
  VEX identifiers (`@my_attr`, not `@my.attr`).
- `ch()`/`chramp()` channel references resolve to the wrangle's (or node's)
  parameters at cook time — they make the code UI-driven.
- In wrangles the `@`-attribute binding happens at compile time: assigning
  `@foo` creates/overwrites the attribute; reading an unset attribute returns
  the default of its type (e.g. `vector(0)`).
- Integer division is C-style: `@Cd.r = @ptnum / 10` truncates. Use `float`
  casts or `f@` variables.
- Wrangles compile per-Houdini-version; don't assume newer VEX features exist
  in old releases.

## References

- VEX language: https://www.sidefx.com/docs/houdini/vex/
- VEX functions: https://www.sidefx.com/docs/houdini/vex/functions/
- Attribute Wrangle node: https://www.sidefx.com/docs/houdini/nodes/sop/attribwrangle.html
- VEXpressions: https://www.sidefx.com/docs/houdini/vex/expressions.html

## Review checklist

1. Typed prefixes on every custom attribute (`f@`, `i@`, `v@`, `s@`).
2. `@P` implicitly exists; `@N`, `@Cd` don't always — guard or compute.
3. `ch()`/`chramp()` parameter names must match the node's parms.
4. Integer division / type coercion pitfalls.
5. Multithreading: no order-dependent state across points unless using
   Detail mode + arrays.