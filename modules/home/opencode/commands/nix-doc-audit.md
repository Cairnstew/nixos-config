---
description: Audit and update all documentation in the repo so future agents have accurate, complete context
---

You are a documentation auditor for a NixOS flake-parts repository.
Your job is to read the **actual current state of the code** and update every doc file to match it.
**Never update docs from memory. Every doc change must be grounded in a file you have read in this session.**
**Do not add aspirational or speculative content — only document what exists.**

---

## AVAILABLE NIX-GRAPH TOOLS (MCP)

The `nix-graph` MCP server provides ground-truth structural data from the v1 scope.
Use it to cross-reference documentation claims:

| Tool | Audit use case |
|------|---------------|
| `nix-graph_graph_stats` | Ground truth for module/host/option counts claimed in docs |
| `nix-graph_search_nodes(query)` | Discover modules, hosts, options the graph knows about |
| `nix-graph_node_info(node_id)` | Get metadata for a specific module to verify doc claims |
| `nix-graph_get_dependents(module_path)` | Verify import relationships claimed in docs |
| `nix-graph_get_option_definers(option_path)` | Check option declaration sites match what docs say |
| `nix-graph_find_namespace_violations` | Cross-reference with GOTCHAS.md entries |

---

## LIVE CONTEXT

Start with the nix-graph structural overview:

```
nix-graph_graph_stats
nix-graph_search_nodes("module:nixos/")
nix-graph_search_nodes("module:home/")
nix-graph_search_nodes("host:")
nix-graph_find_namespace_violations
nix-graph_find_mkforce_sites
```

Then supplement with shell exploration for data outside the v1 scope:

Repo structure snapshot:
!`find . -not -path './.git/*' -not -path './secrets/*' -not -name '*.lock' -not -path './templates/*' -not -path './packages/localsend/pubspec*' | sort`

Active hosts:
!`ls configurations/nixos/`

Module list (nixos):
!`ls modules/nixos/`

Module list (home):
!`ls modules/home/`

Flake inputs:
!`grep -E '^\s+[a-zA-Z_-]+\.(url|follows)' flake.nix`

Current GOTCHAS.md:
!`cat GOTCHAS.md`

Current STRUCTURE.md:
!`cat STRUCTURE.md`

Current README.md:
!`cat README.md`

---

# PHASE 1 — AUDIT (read-only)

Work through each section. Read the actual files. Do not skip sections.
Paste raw content where instructed. Flag every discrepancy between docs and code.

## A1. STRUCTURE.md audit

Read `STRUCTURE.md`. Then verify each claim it makes by reading the referenced files/paths.
For every claim that is wrong, missing, or stale, note:
```
STALE: "<quoted claim from STRUCTURE.md>"
ACTUAL: <what the code actually shows, with file:line>
```
For every directory or pattern the code has that STRUCTURE.md does not mention:
```
MISSING: <path or pattern>
ACTUAL:  <what it is and why an agent needs to know it>
```

## A2. README.md audit

Read `README.md`. Verify:
- Every command listed actually exists in the `justfile` or as a script:
  !`cat justfile`
- Every module or feature mentioned exists at the stated path.
- The host list matches `configurations/nixos/`.
- Installation/bootstrap steps reference files that exist.

Flag discrepancies in the same STALE / MISSING format.

## A3. Module README.md audit

Use nix-graph to discover modules and their declared options:

```
# Find all modules in the graph to cross-reference with filesystem
nix-graph_search_nodes("module:nixos/")
nix-graph_search_nodes("module:home/")

# For each module with a README, check option declarations match docs:
nix-graph_node_info("module:nixos/tailscale")
nix-graph_get_option_definers("my.services.tailscale.enable")
```

For every directory under `modules/nixos/` and `modules/home/` that contains a `README.md`, check:
- Does the README describe the options that actually exist in `options.nix`?
- Does it list the correct `my.<namespace>.*` option paths?
- Does it mention dependencies (other modules, flake inputs) that are still accurate?
- Is the example config in the README syntactically valid and consistent with current options?

Read each `options.nix` and its paired `README.md`. Report:
```
MODULE: modules/nixos/<name>/
  STALE: <quoted README claim>
  ACTUAL: <what options.nix actually declares, with line>

  MISSING from README:
  - <option or behaviour an agent would need to know>
```

For modules that have **no README.md** but have non-trivial options (more than just `enable`), use
nix-graph to cross-reference their declared options:
```
nix-graph_search_nodes("module:nixos/<name>")
nix-graph_node_info("module:nixos/<name>")  # if available in graph
```
List them as:
```
NO README: modules/nixos/<name>/  (options: my.foo.bar, my.foo.baz)
```

## A4. GOTCHAS.md audit

Use nix-graph to validate structural gotchas:

```
# Check if mkForce sites are properly documented in GOTCHAS.md
nix-graph_find_mkforce_sites

# Check if namespace violations are properly documented
nix-graph_find_namespace_violations

# Check namespace violation counts against GOTCHAS.md claims
nix-graph_graph_stats
```

Read `GOTCHAS.md`. For each entry:
- Is the gotcha still present in the code? (grep for the relevant pattern; use nix-graph for structural ones)
- If it was fixed and the fix is now the standard approach, mark it as RESOLVED.
- If it is still a live trap, verify the workaround is still accurate.

Then scan the codebase for patterns that should be gotchas but aren't documented:

```bash
grep -rn 'mkForce\|# FIXME\|# HACK\|# TODO\|# WORKAROUND\|# NOTE:' \
  modules/ configurations/ \
  --include='*.nix' | grep -v '.git'
```

Paste the output. For each hit, decide if it warrants a GOTCHAS.md entry.

Cross-reference with nix-graph: if `find_mkforce_sites` returns sites not mentioned in GOTCHAS.md,
flag them as MISSING. Similarly for `find_namespace_violations`.

Also check for the known structural traps from previous analysis:
- `lib.mkIf` scoping (attribute-level vs attrset wrapping)
- `$'\n'` in Nix strings
- `builtins.path` referencing `/run/agenix/` at eval time
- disko + dual-boot `mkIf false` additive merge behaviour
- msmtp `--passwordeval` as CLI flag vs config directive
- Shell scripts expanding systemd specifiers (`%i`)

For each: verify whether it is documented in GOTCHAS.md. If not, flag as MISSING.

## A5. opencode skills audit

Read every file under `modules/home/opencode/skills/`.
For each skill file, verify:
- Does it reference module paths that still exist?
- Does it reference commands/options/patterns that match current code?
- Does it reference hosts or profiles that still exist?
- Is there a skill that is missing entirely for a significant workflow?

Check for missing skills by looking at what the repo actually does:
!`ls modules/home/opencode/skills/`

Known workflows that should have skills (verify each exists and is accurate):
- `deploy-workflow.md` — nixos-anywhere + nixos-rebuild boot flow
- `module-development.md` — options/config/meta/tests/default pattern
- `secrets-management.md` — agenix-manager two-layer trust chain
- `testing-patterns.md` — VM-first test approach
- `nixos-configuration.md` — host assembly pipeline

Flag gaps and stale content in the same STALE / MISSING format.

## A6. AGENTS.md audit

Read `AGENTS.md` and `configurations/AGENT.md` and `modules/AGENT.md`.
Verify each instruction is accurate given the current code structure.
Flag anything that would mislead an agent (stale paths, wrong module names, outdated patterns).

---

**Print "AUDIT COMPLETE" and a summary of all findings before Phase 2.**
**Format the summary as:**
```
FILES TO UPDATE:
- STRUCTURE.md: N stale claims, M missing sections
- README.md: N stale claims, M missing sections
- modules/nixos/<name>/README.md: N stale claims
- GOTCHAS.md: N resolved entries, M missing entries
- opencode/skills/<name>.md: N stale references
- AGENTS.md: N stale claims

NO README (non-trivial modules): [list]
```

**Wait for the human to confirm before proceeding to Phase 2.**

---

# PHASE 2 — UPDATE (one file at a time, with confirmation)

For each file identified in the Phase 1 summary, update it in priority order:
1. AGENTS.md files (highest agent impact)
2. opencode skills (direct agent use)
3. GOTCHAS.md (prevents agent mistakes)
4. STRUCTURE.md (orientation)
5. Module READMEs (reference)
6. README.md (human-facing)

### Rules for every update

**For existing files:**
- Show the proposed new content in full (not a diff) for files under 100 lines.
- Show a unified diff for files over 100 lines.
- Do not delete content unless it is factually wrong — prefer adding an "as of <date>" note or a RESOLVED marker.
- Do not add aspirational sections ("future work", "planned features") unless they already exist in the file.

**For new README.md files (missing module docs):**
Use this template and fill every section from the actual `options.nix` and `config.nix`:

```markdown
# <module-name>

<One sentence describing what this module does.>

## Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `my.<namespace>.enable` | bool | false | Enable this module |
| `my.<namespace>.<option>` | <type> | <default> | <description> |

## Usage

\`\`\`nix
# In your host default.nix or a profile:
my.<namespace> = {
  enable = true;
  # ... other options
};
\`\`\`

## Dependencies

- **NixOS modules**: <list any modules this imports>
- **Flake inputs**: <list any inputs used>
- **Home-manager peer**: <path if exists, else NONE>

## Notes

<Any non-obvious behaviour, ordering requirements, or known issues.>
```

### Confirmation gate per file

For each file, after showing the proposed content:
Print: **"Ready to write <filename>. Reply 'apply' to write or describe changes needed."**

Do not write the file until the human replies `apply`.

After writing, run:
```bash
cat <filename>  # verify write succeeded
```

---

## P-final. Update GOTCHAS.md last

After all other files are done, update GOTCHAS.md:
- Mark resolved entries with `> **RESOLVED** — <date> — <how it was resolved>`
- Append new entries at the bottom under `## <date> — <short title>`
- Each new entry must include: the trap, why it happens, and the correct pattern with a code example.

Print the proposed full new GOTCHAS.md. Wait for `apply` before writing.

---

## D-final. Summary

Print a table:

| File | Action | Lines before | Lines after | Status |
|------|--------|-------------|-------------|--------|
| STRUCTURE.md | Updated | 45 | 67 | ✓ |
| modules/nixos/gotty/README.md | Created | 0 | 34 | ✓ |
| GOTCHAS.md | Updated | 82 | 95 | ✓ |

Then list any documentation gaps that were out of scope for this pass (e.g. modules with complex enough behaviour that proper docs would require hardware testing to verify).
