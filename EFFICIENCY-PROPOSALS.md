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
