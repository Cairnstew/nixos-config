# FORK.md — vendored fork of @hueyexe/opencode-ensemble

**Status:** ACTIVE fork. This repo installs a build-time-patched copy of
`@hueyexe/opencode-ensemble@0.16.1` as a **local opencode plugin** instead of
installing the npm package.

## Why this fork exists

The wake-path defect: every team *continuation* — wake-lead, member message
delivery, broadcast delivery, shutdown nudge, watchdog stall/chatty nudges,
idle-without-report nudge, and the pending-message wake loops — re-prompts a
session with `promptAsync({ sessionID, parts })` and **no agent/model**. The
session then silently falls back to the global default after its first turn.
In this repo that means ensemble chains resolve the intended model (mimo lead /
triage, with OPA and caps) for turn one only; every continuation ran on
`deepseek-v4-flash` (measured: $3.11 lead session = 176/176 continuation turns
flashed; 34% of reviewer sessions flipped mid-session, 13.8% of reviewer turns).

**Upstream has not fixed this.** Verified 2026-08-26 against the published
0.17.0 dist (latest): all five promptAsync omission-site groups are still
present (`wake-lead`, member delivery, broadcast, shutdown nudge, pending-message
wakes). Three minor releases after ours — this is an intentional fork, not a
stopgap-until-upstream.

## Fork base

| | |
|---|---|
| Package | `@hueyexe/opencode-ensemble` |
| Version | **0.16.1** |
| Artifact | `https://registry.npmjs.org/@hueyexe/opencode-ensemble/-/opencode-ensemble-0.16.1.tgz` |
| sha256 | `2f3268a2d87ed1918b0fc6d20a2bc4386dd0b796ebf63d00442cbb5119a94a98` |
| Published | 2026-08-15 |
| Dist | single-file `dist/index.js` (node-core imports only; exports the plugin fn) |

Chosen over 0.15.0 (the previously-pinned version) because 0.16.1 already
carries fixes this repo wants — team-spawn agent-null normalization (issue #28),
`claim_task` auto-claim (issue #27), task-board integrity — and ahead of 0.17.0
(published later; no wake-path fix). Drift audit 0.15.0→0.16.1: 13 files; the
other changes are dashboard verbose-activity UI (`activity.ts` + `dashboard*`),
SDK `session.messages`/`get` wrappers (`client.ts`/`types.ts`), a bundler-safe
`node:sqlite` require spelling (`db.ts`), and cleanup bookkeeping (`index.ts`).
None affect the wake path, spawn semantics, or pacing.

## What the patch does

`modules/home/opencode/patches/opencode-ensemble.py` — a fail-loud build-time
patch (same discipline as the modpack `patches/<mod>.py` + `patch-jar.nix`):

1. **Migration 9** — `ALTER TABLE team ADD COLUMN lead_model TEXT` via the
   plugin's own `MIGRATIONS`/`user_version` machinery.
2. **team_create snapshot** — after the team row insert, read the lead session's
   creation-time model from the opencode `message` table and store
   `team.lead_agent` / `team.lead_model` (one-off read; best effort).
3. **Ten wake sites wrapped** — every continuation `promptAsync({sessionID,
   parts})` becomes `promptAsync(__ensembleWakeArgs(db, {sessionID, parts}))`;
   the helper re-attaches the target session's `agent`/`model`:
   - lead → `team.lead_agent` / `team.lead_model` (with the message-table read
     as fallback when the snapshot is null, e.g. legacy teams);
   - member → `team_member.agent` / `team_member.model`.
   On any DB/parse failure the helper returns the options unchanged = today's
   default behavior (the defense-in-depth failure mode is safe degradation).

If any anchor in the pinned dist is missing, the Nix build **fails loudly**
instead of silently shipping a wrong patch, and `tests/opencode-ensemble-fork_test.nix`
re-asserts the post-conditions at nixtest time.

## How it's wired

- `fork.nix` — fetches the pinned tarball, extracts `dist/index.js`, runs the
  patch, `node --check`s the result (ESM), outputs the patched file.
- `config.nix` `pluginFiles.opencode-ensemble` — installs the patched bundle to
  `~/.config/opencode/plugins/opencode-ensemble.js` (auto-discovered).
- `modules/nixos/homeManager/config.nix` `plugins = [ ]` — the npm spec was
  REMOVED. A similar-named npm spec and local file **BOTH load** (opencode docs)
  → double-registered tools and the unfixed upstream. An assertion in
  `modules/home/opencode/tests.nix` guards the empty state.

## Fork policy — read before any ensemble version bump

1. Re-check upstream for a wake-path fix: grep the newest published dist for
   `promptAsync({ yes sessionID` without agent/model. If fixed → drop the fork,
   restore the npm spec, delete `fork.nix`/`patches/`, remove the assertion,
   remove `lead_model` migration need, update this file to REVOKED.
2. If not fixed → re-base the fork on the newer tarball:
   - update the sha256 + version in `fork.nix` (and this table);
   - re-run the patch — anchors fail loudly where the new dist moved them;
     re-derive those anchors (this file's patch inventory + the nixtest are the
     map);
   - re-run the 0.15→<new> drift audit notes above;
   - keep migration 9 idempotent (already applied on existing DBs);
   - run nixtests + a live spawn-batch verification (see below).
3. Any opencode version bump that touches the plugin API surface re-runs the
   same nixtest + live verification (triage-capture schema-fragility smoke test
   already covers the shared `message`-table read).

## Verification baseline (live, 2026-08-27)

- nixtest `opencode-ensemble-fork-tests` ✅ (11/11 wake sites wrapped, spawn
  intact, migration present, ESM parses).
- `node --check` + import smoke (patched bundle loads, default export is a fn) ✅.
- Nix build of `fork.nix` in the sandbox ✅.
- Live spawn-batch verification: see Tier-1 report §Verification (isolated team
  spawn exercised wake continuations against the patched bundle; the switch
  deploying it to the running environment is gated on sign-off).

## Rollback plan (if the fork breaks post-switch)

The fork is inert at the config level — at worst opencode logs plugin errors and
runs without team tools (host never fails to boot because of it). To revert:

1. Fastest: `sudo nixos-rebuild rollback` (previous generation — the fork isn't
   in it).
2. Clean: revert the fork commits (`git revert` of the config.nix/wiring +
   homeManager `plugins=[]` commits, i.e. restore the npm spec) and re-activate
   (switch stays gated). opencode restarts with the upstream npm plugin.
3. Verify: team tools return (`team_create` callable), no plugin errors in the
   opencode log.

## Residual risk (accepted, documented)

- The `message`-table read (used once at team_create + as wake fallback) has the
  same schema-fragility as `triage-capture.ts` — already a documented GOTCHAS
  with a version-bump smoke test.
- Upstream API drift on opencode bumps — the same risk the bare npm pin had,
  now with our fork as the diff surface (policy §3).