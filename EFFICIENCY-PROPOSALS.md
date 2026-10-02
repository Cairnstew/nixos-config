# EFFICIENCY-PROPOSALS.md — Efficiency-lens proposals (record-only)

Proposals from the self-improvement checkpoint's **efficiency lens** land here.
This file is the counterpart to `GOTCHAS.md`/RUN LOGs, but is **proposal-only**:
an entry names a tool/skill/command/config idea that would collapse a genuinely
repeated pattern, cites the quantitative evidence (tool-call counts / token / cost
from the proposing session's own `opencode.db` row), and is **never built in the
session that wrote it**.

Rules:
- Append-only; one proposal per entry, newest last. Never build the proposed
  thing in-session (the efficiency lens only records).
- Entries go through `tools/self-improve-commit.sh` (allow-listed here) — the
  same mechanical evidence/append-only checks apply; evidence is the DB query
  output rather than a `file:line`.
- Proposals are ideas for a human (or a future session) to act on, not
  commitments. Anything ultimately adopted is built as normal task work, not via
  this log.

---

## 2026-09-22 — one-shot `git-commit` opencode command to collapse the 96-bash-call commit workflow

- **Idea**: a repo `git-commit` command (modules/home/opencode/commands/) that runs the whole commit workflow — status → `nix fmt` → stage (secrets-guard) → diff review → prefix commit → `nixpkgs-fmt --check`/`nix flake check --no-build` → push → `ci-monitor watch` — as one invocation with interactive confirmation gates, instead of the agent hand-executing every step.
- **Evidence** (this session, `ses_f35510bb6ffelx0M1mWsyMujXg`, via `opencode.db`): 96 `bash` tool calls vs 7 `read` + 5 `edit`; cost $0.108 / 241K input / 48K output tokens. The dominant repeat cluster: `git status`/`git diff` (8+), `nixpkgs-fmt`/`nix shell nixpkgs#…` wrappers (5+), `git rebase --continue` + conflict grep/edit rounds (3 conflicts → ~12 calls), `gh run list`/`ci-monitor` + `export GH_TOKEN=…` bootstrap (6+). A command encoding the workflow + conflict-resolution loop (grep markers → keep-HEAD resolution → `GIT_EDITOR=true rebase --continue`) and the `GH_TOKEN`-from-ragenix bootstrap would collapse these into few calls per commit and make the pre-push gates deterministic instead of rediscovered each session.
- **NOT built this session** (proposal-only). Note: the workflow's `nixpkgs-fmt`/`python3` PATH assumptions are stale on laptop — either the command must run tools via `nix shell nixpkgs#…` or the home-module should add them to `home.packages` (cf. GOTCHAS.md:1091).

---

## 2026-09-25 — single-suite nixtest scoping recipe to collapse repeated full-suite runs while iterating one test

- **Idea**: a `just nixtest <suite-regex>` recipe (in `justfile`) — or at minimum a documented one-liner in `modules/flake-parts/nixtest.nix` — that runs `nix run .#nixtests-run -- -s '<everything-else-regex>'` so an agent iterating one suite (e.g. `fork-tests`) doesn't re-run the whole 6-suite/14-test runner. nixtest only ships `-s/--skip` (verified `nix run .#nixtests-run -- --help`; no positive filter), so the recipe must invert the regex; a suite filter would be: `-s 'core|model-fallback|select|slices'` to run only fork+vendor suites.
- **Evidence** (this session `ses_f2ac3912dffei7djBnMcG4QMJE` via `opencode.db`: cost $0.127 / 331K in / 71K out / 361 parts / 101 tool calls): the hardening task ran `nix run .#nixtests-run` **4×** iterating a single suite (fork-tests) while creating the new vendor-guard suite — each invocation rebuilt+ran all 14 tests when only 1-2 mattered. The `-s` flag works today (the app forwards args), so the ask is a one-line recipe + doc, not new tooling. Related: `nix flake check` never runs nixtests at all (GOTCHAS 2026-09-25 entry) — the same recipe should be the documented "suite gate" after vendored-artifact/fork changes.
- **NOT built this session** (proposal-only).

---

## 2026-09-29 — `hm-opt` recipe/command to collapse the repeated long flake-attr-path eval/build/verify loop

- **Idea**: a `just hm-opt <host> <hm-option-path>` recipe (or an opencode command) that stages the tree, evaluates `.#nixosConfigurations.<host>.config.home-manager.users.<user>.<path>`, and — when the option's value is a `types.path` store artifact — **builds** it and immediately runs the generated-file sanity check (awk min-indent scan + `python3 -c 'import ast; ast.parse(...)'`). The point is to bundle the three things that currently take separate `bash` calls, and to hide that `nix eval --raw` on a `types.path` prints a store path **without materialising the file** (GOTCHAS 2026-09-29).
- **Evidence** (this session `ses_f13bedaeeffeTOlB9RhFXTFvsj` via `opencode.db`: cost $0.3495 / 1,199,737 in / 164,902 out / 98,608 reasoning / 295 tool calls = bash 165, read 41, edit 37, write 23): **35 of 165 bash calls (21%)** repeat the same ~110-char path `.#nixosConfigurations.desktop.config.home-manager.users.seanc.…` — 25× `nix eval --raw`, 5× `nix build`, 3× `nix eval --json`, 2× other. A further **16 bash calls** belong to the generated-script verify loop (`awk` indent scan / `ast.parse`), and because every `tag.nix` edit changes the derivation hash, each edit re-ran the whole build→check sequence. Folding path-resolution + build-if-path + syntax/indent check into one invocation would cut ~51 calls (31% of all bash) to a handful per edit, and would make the "did it actually materialise?" question impossible to get wrong.
- **NOT built this session** (proposal-only).

---

## 2026-09-29 — efficiency-lens query bootstrap (skill/command) so every SELF_IMPROVE session stops rediscovering the `opencode.db` schema

- **Idea**: a small skill (or `just lens-stats [--session <id>]`) that runs the fixed query set the efficiency lens needs — locate the current session row (`session.cost` / `tokens_input` / `tokens_output` / `tokens_reasoning` / `tokens_cache_read` / `tokens_cache_write`), then the `part` tool-call histogram via `json_extract(data,'$.tool')`, then the top command prefixes via `json_extract(json_extract(data,'$.state.input'),'$.command')` — with the `session_id` resolved automatically from the most recently updated row.
- **Evidence** (this session `ses_f13bedaeeffeTOlB9RhFXTFvsj` via `opencode.db`): **11 bash calls** went to `opencode.db` alone, of which ~6 were schema rediscovery (`.tables`, `PRAGMA table_info(session)`, `PRAGMA table_info(part)`, then trial `json_extract` paths) before the real four queries could run. Because `SELF_IMPROVE=true` is the default in `modules/home/opencode/agents/build.md:59`, this cost is paid **every session**, not just this one — the schema does not change, only the session id does.
- **NOT built this session** (proposal-only).

---

## 2026-10-02 — `theme-probe`: a lib-direct colour/palette probe, so lib-level checks stop paying a full flake evaluation (and can't hit the Nix binding traps)

- **Idea**: a `just theme-probe` recipe (or small skill) with two modes. `--lib` imports `lib/theming.nix` directly against `nixpkgs.lib` and prints, in **one** call, the resolved palette for every scheme in the catalog plus its contrast table (fg / muted / accent / error vs background) and a `mkColors` override demo — no flake involved at all. `--host <host> [--attr <path>]` does the flake-based module-level read, wrapping the `git add -A` + `builtins.getFlake` + `.#nixosConfigurations.<host>.config` boilerplate that every probe this session repeated by hand. Building the attribute set internally (rather than interpolating a user-supplied expression) makes the two binding traps below unrepresentable.
- **Why the split matters**: `lib/color.nix` and `lib/theming.nix` take only `{ lib }` and touch nothing in the flake, yet **every** colour check this session still went through `builtins.getFlake`, so each of the ~25 probes re-evaluated the whole flake (measured 60-90 s apiece) to read a pure function.
- **Evidence** (this session `ses_f0646f616ffeDlMTlgaEvbYwBh` via `opencode.db`: cost $0 (free model), 862,155 in / 76,520 out / 48,758 reasoning / 61,615,123 cache-read, **273 tool calls** = bash 197, edit 37, write 31, todowrite 4, grep 3, skill 1, nix-lint 1): the single largest repeated command shape is `cd /home/seanc/nixos-config && nix eval --impure --json --expr '…'` at **25 calls**, plus **8** variants prefixed `git add -A &&` and **5** more prefixed `git add -A lib/ &&` — **38 of 197 bash calls (19%)** are the same ~110-char `getFlake`-plus-attr-path probe. Of those, **~8 were failed evaluations costing a full flake eval each**, caused by two pure-syntax traps now recorded in GOTCHAS: `f { … }.attr` binds `.attr` to the attrset literal instead of `f`'s result, and `lib.mapAttrs (_: one)` passes each attrset *value* where a *name* was wanted. A probe tool would eliminate both by construction, and would cut ~38 calls to roughly one per distinct question.
- **NOT built this session** (proposal-only).
