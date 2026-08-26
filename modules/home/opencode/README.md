# Opencode — AI Coding Agent

Home-manager module for [opencode](https://opencode.ai), an AI coding agent for
the terminal, with support for 15+ LLM providers, custom skills, agents, and MCP integration.

## Features

- **15+ LLM Providers**: Local (Ollama) and cloud providers (Anthropic, OpenAI, Google, Groq, etc.)
- **Custom Skills**: Context-aware instructions for common tasks
- **Custom Agents**: Specialized agents with different permissions and models
- **MCP Integration**: Model Context Protocol servers for extended capabilities
- **Agenix Integration**: Secure API key management

## Supported Providers

| Provider | Type | Key mechanism |
|----------|------|---------------|
| Ollama | Local | No key needed |
| OpenAI | Cloud | `OPENAI_API_KEY` env var |
| Anthropic | Cloud | `ANTHROPIC_API_KEY` env var |
| Google (Gemini) | Cloud | `GOOGLE_GENERATIVE_AI_API_KEY` env var |
| Groq | Cloud | `GROQ_API_KEY` env var |
| Mistral | Cloud | `MISTRAL_API_KEY` env var |
| xAI (Grok) | Cloud | `XAI_API_KEY` env var |
| Together AI | OpenAI-compatible | `{file:...}` substitution |
| OpenRouter | OpenAI-compatible | `{file:...}` substitution |
| Fireworks | OpenAI-compatible | `{file:...}` substitution |
| Cerebras | OpenAI-compatible | `{file:...}` substitution |
| DeepInfra | OpenAI-compatible | `{file:...}` substitution |
| Clarifai | OpenAI-compatible | `{file:...}` substitution |
| Azure | Cloud | `AZURE_API_KEY` env var + endpoint |
| OpenCode Go | First-class | `keyFile` → `auth.json` (not in provider block) |
| OpenCode Zen | First-class | `keyFile` → `auth.json` (not in provider block) |

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `my.programs.opencode.enable` | `false` | Enable opencode |
| `my.programs.opencode.model` | `null` | Active model (`provider/model-id`) |
| `my.programs.opencode.ollamaModels` | `{}` | Ollama models to register |
| `my.programs.opencode.ollamaBaseURL` | `http://127.0.0.1:11434/v1` | Ollama endpoint |
| `my.programs.opencode.openai.keyFile` | `null` | Path to OpenAI API key file |
| `my.programs.opencode.anthropic.keyFile` | `null` | Path to Anthropic API key file |
| `my.programs.opencode.google.keyFile` | `null` | Path to Google API key file |
| `my.programs.opencode.groq.keyFile` | `null` | Path to Groq API key file |
| `my.programs.opencode.mistral.keyFile` | `null` | Path to Mistral API key file |
| `my.programs.opencode.xai.keyFile` | `null` | Path to xAI API key file |
| `my.programs.opencode.together.keyFile` | `null` | Path to Together AI key file |
| `my.programs.opencode.openrouter.keyFile` | `null` | Path to OpenRouter key file |
| `my.programs.opencode.fireworks.keyFile` | `null` | Path to Fireworks key file |
| `my.programs.opencode.cerebras.keyFile` | `null` | Path to Cerebras key file |
| `my.programs.opencode.deepinfra.keyFile` | `null` | Path to DeepInfra key file |
| `my.programs.opencode.clarifai.patFile` | `null` | Path to Clarifai PAT file |
| `my.programs.opencode.azure.keyFile` | `null` | Path to Azure API key file |
| `my.programs.opencode.azure.endpoint` | `null` | Azure OpenAI endpoint |
| `my.programs.opencode.azure.deployment` | `null` | Azure deployment name |
| `my.programs.opencode.mcp` | `{}` | MCP server configurations |
| `my.programs.opencode.modelFallback.enable` | `false` | Usage-aware model fallback |
| `my.programs.opencode.modelFallback.chains` | `{}` | Ordered fallback chains per agent (`model` + optional `maxRollingPercent` / `maxWeeklyPercent` / `maxMonthlyPercent`) |
| `my.programs.opencode.modelFallback.syncEnsembleProjectFile` | `false` | Rewrite `<repoDir>/.opencode/ensemble.json` before dispatch so ensemble spawns use chain-resolved models |
| `my.programs.opencode.modelFallback.repoDir` | `~/nixos-config` | Repo whose project-level ensemble override receives resolved models |

Chain entries additionally accept a `pacing` block — see
[Pace-based caps](#pace-based-caps-weeklymonthly-only) below.

## Usage-Aware Model Fallback

`my.programs.opencode.modelFallback` ships the `opencode-model-select`
selector. It reads the cached OpenCode Go usage snapshot
(`~/.cache/opencode/go-usage.json`, refreshed every 5 minutes by
`opencode-go-usage.timer`) and resolves an ordered chain per agent: **the
first entry whose percent caps are all satisfied wins**. The last entry of a
chain must be cap-free — it is the always-eligible safety net (asserted in
`tests.nix`).

Thresholds are **percent-based**: the Go usage API exposes only
status/percent/resetsAt per window (rolling ~5h, weekly, monthly) and no
dollar amounts, so USD budgets cannot be enforced here by construction.
Note that opencode's own docs (https://opencode.ai/docs/go) state the intent
that you can "continue using free models past the limit" — which is exactly
why every chain's tail is a cap-free free model: when paid entries exhaust,
dispatch degrades to free instead of erroring.

### Pace-based caps (weekly/monthly ONLY)

Chain entries can opt into **pace-based** weekly/monthly caps: the allowed
usage ceiling scales with how much of the window's period has elapsed
(`cap = min(100, elapsedPercent + buffer)`, inert while
`elapsedPercent < floor`), so front-loading early in a week tightens the cap
automatically instead of waiting for a fixed threshold.

```nix
chains.default = [
  { model = "opencode-go/deepseek-v4-flash";
    maxWeeklyPercent = 80;              # static hard ceiling — pacing can
                                        # never exceed this even with buffer
    pacing = { enable = true; }; }      # floor = 5, buffer = 10 defaults
  { model = "opencode-go/ox-alpha-free"; }
];
```

Semantics (`modules/home/opencode/fallback.nix`, program in
`modules/home/opencode/model-select.jq`):

- **`pacing.enable = false` (the default) means static caps only** — the
  flag gates the pace term. BUG FIX 2026-08-26 (self-improve-usage Tier 0
  §2c / Tier 1 Task 2): the pace term previously applied even when the flag
  was false, so "shipped disabled" pacing was de-facto always-on and whole
  chains resolved BLOCKED at moderate usage. Regression test:
  `tests/opencode-model-fallback_test.nix` (`nix run .#nixtests-run`).
  Diagnostic signature if a flag-is-not-read bug recurs elsewhere: a chain
  resolves BLOCKED while ROLLING sits near 0% and every static cap passes.
- Effective window cap = `min(staticCap, paceCap)`; pacing can only tighten.
- `paceCap = min(100, elapsedPercent + buffer)`, where
  `elapsedPercent = clamp((now − periodStart) / periodLength × 100, 0, 100)`.
- Below `floor` percent elapsed, pacing is entirely inert for that entry.
- `periodStart` derives from the snapshot's `resetsAt` alone — no new state:
  weekly = `resetsAt − 7d` (**exact**, anchored Monday 00:00 UTC);
  monthly = `resetsAt − 30d` (**approximate** ±1 day ≈ ±3 pp of cap — the
  provider does not expose a period-start field, adjacent endpoints are 404,
  and the true monthly period length is unverified until its first observed
  reset on 2026-09-19).
- Rolling is **excluded**: it is a trailing 5-hour *sliding* window
  (`resetsAt = now + 5h` on every poll — nine samples across two days), so it
  has no anchor to pace against. Entries setting `pacing.enable` must
  constrain `maxWeeklyPercent` or `maxMonthlyPercent`; this is asserted in
  `tests.nix` and throws at eval otherwise.

**Why pacing ships disabled:** both production chains currently run with
static caps only. Weekly pacing should be flipped to `enable = true` only
after tonight-style rollover is observed once (next `weekly.resetsAt` must
read `2026-08-31T00:00:00Z` verbatim from the API); monthly only after the
2026-09-19 reset confirms its true period length. The two evidence gates are
independent. (Until 2026-08-26 this paragraph was aspirational — the dead
flag above meant pacing ran regardless; with the fix it is literally true.)

Boundary behavior is validated against synthetic snapshots at controlled
times (elapsed 0%, just-under/just-over floor, stale cache past `resetsAt`,
static-ceiling precedence) — see the boundary harness transcript referenced
in `/tmp/opencode/model-fallback-pacing/`.

Two consumption paths:

1. **Top-level invocations** — the `opencode` wrapper injects
   `--model <resolved>` unless you already passed `-m/--model`, or set
   `OPENCODE_MODEL_SELECT_OFF=1`.
2. **Ensemble spawns** — with `syncEnsembleProjectFile = true`, the selector
   rewrites `<repoDir>/.opencode/ensemble.json` (gitignored) with
   chain-resolved `modelsByAgent`. The ensemble plugin merges project config
   over the HM-managed global one.

### Scope caveats (documented deliberately)

- The project-level override only applies when opencode's working directory
  resolves inside `<repoDir>`; dispatches from other trees silently keep the
  static global model.
- The ensemble plugin reads its config **once at process start**
  (`loadConfig` in `src/index.ts`), so a synced override reaches only
  processes started afterwards. Long-running `opencode serve --attach`
  sessions need a restart to pick up new selections; within a live session,
  pass an explicit `model=` argument to `team_spawn` instead (it outranks
  `modelsByAgent` in the plugin's resolution order).
- `.opencode/ensemble.json` being runtime-mutated inside a git-tracked
  directory is an intentional imperative exception — see GOTCHAS.md.

### Blocked chains — no free-tier terminal (`blockedTerminal`)

Some pipelines must NOT degrade when their chain exhausts. A chain whose LAST
entry is `{ blockedTerminal = true; }` (no `model`) resolves to a
distinguishable **BLOCKED** outcome — the selector prints a stderr reason and
exits **5** — instead of silently falling to an always-eligible free model.
Use this for decision-making pipelines (e.g. the learning-promoter, which
auto-merges to the repo), not for build/explore agents where free-tier
fallback is fine.

The learning-promoter watcher consumes this: before dispatching it resolves
the chain, and on exit 5 it **stops its own systemd timer**
(`learning-promoter-watcher.timer`) rather than dispatching. Resume is
**manual by design**:

```
systemctl --user start learning-promoter-watcher.timer   # after usage resets
```

A stopped timer runs nothing at all — including the staleness reconciliation,
which would otherwise force-reject queued learnings during a long rate-limit
wait. Distinguishing "stopped because usage-blocked" from "stopped for any
other reason" would need extra state and re-create exactly that class of bug,
so automated resume was rejected deliberately.

### `/learning-promote` agent binding

`commands/learning-promote.md` binds `agent: learning-promoter` in its
frontmatter. Before this, watcher dispatches executed as the default `build`
agent — and a live negative-direction test proved build's
`goals_learning_promote` call passes opencode's permission layer (the goals
server rejected it only on application-level grounds). So the pre-fix window
was a REAL capability gap in the agent-layer isolation model, unexploited
only because the watcher was disabled the whole time. When auditing the
defense-in-depth property: exactly two agents are promote-capable by design
(commit `9733f8b`, enforced by `tests.nix`) — `build` and
`learning-promoter`; every triage/reviewer role denies the tool.

### Known limits — what usage protection does NOT cover

The self-improvement chains (`learning-promoter` + triage roles) protect
**automated** promotion paths. They deliberately do NOT cover the `build`
agent, which can also reach `goals_learning_promote`:

- Why not chain-coverage: `build` is the general-purpose primary agent for
  all coding work; gating its model on pipeline exhaustion would halt normal
  work near every rate-limit window.
- What enforces safety on the automated path: the watcher's
  `/learning-promote` dispatch binds `agent: learning-promoter`
  (live-verified both directions, 2026-08-24), so the watcher never
  exercises build's access. THIS is enforced.
- What is NOT enforced, only observed: build's promote access being
  exercised solely under human supervision (interactive TUI sessions, or
  manually launched commands like `triage-review`, which currently has no
  `agent:` binding and therefore runs as build). Nothing technical prevents
  a FUTURE unbound command or skill from routing a headless dispatch through
  build into promotion territory — that would silently recreate the pre-fix
  exposure. Mitigation is the GOTCHAS rule ("any command whose semantics
  depend on a specific agent MUST set `agent:`"), which is documentation,
  not enforcement.

Scope statement: "usage-aware protections for the self-improvement pipeline"
means the watcher-dispatched promotion loop and the triage subagents — not
build-agent sessions generally, and not manually launched workflows.

### Example

```nix
my.programs.opencode.modelFallback = {
  enable = true;
  chains.default = [
    { model = "opencode-go/deepseek-v4-flash"; maxWeeklyPercent = 80; }
    { model = "opencode-go/mimo-v2.5"; maxWeeklyPercent = 95; }
    { model = "opencode-go/ox-alpha-free"; }          # safety net, no caps
  ];
  # Decision-making pipeline: no free tier — exhaustion => BLOCKED (exit 5).
  chains.learning-promoter = [
    { model = "opencode-go/mimo-v2.5"; maxRollingPercent = 85; maxWeeklyPercent = 95; }
    { model = "opencode-go/deepseek-v4-flash"; maxRollingPercent = 70; maxWeeklyPercent = 80; }
    { blockedTerminal = true; }
  ];
};
```

### Evidence basis for MiMo-V2.5 as the pipeline default (read before changing)

MiMo-V2.5 leads the self-improvement chains as a **reasoned default, not a
validated-in-isolation one**: the production evidence that "mimo already ran
triage/promotion successfully" was gathered largely while the old default
chain was *already degraded to mimo via cap exhaustion* (weekly sat at/near
100% throughout that period) — i.e., under degraded conditions, not light-
usage steady state. Capability facts (tool-call + structured output Yes,
1M context, models.dev) are solid; steady-state quality is something to
watch, not something already proven.


## Shopping MCP Servers

The home-manager wiring (`modules/nixos/homeManager/config.nix`) declares three
shopping MCP servers for opencode. Each is **enabled only when its agenix secret
exists** in `modules/nixos/secrets/secrets-manifest.json`, so creating the
secret is what activates the server (create with `agenix-manager new`):

| Server | Purpose | Secret(s) needed | Cost |
|--------|---------|------------------|------|
| `ebay` | eBay + Facebook Marketplace search & listing details (official Browse API) | `ebay-client-id`, `ebay-client-secret` | Free eBay dev keys |
| `amazon` | Amazon offers, buybox, product info, reviews (ShoppingScraper API) | `ssc-api-key` | Paid (credit-based) |
| `keepa` | Amazon price history, deals, sellers (Keepa API) | `keepa-api-key` | Paid (token-based) |

The servers are wired as agenix-guarded `mkIf` entries in the opencode `mcp`
block. The keepa server uses a locally-packaged binary
(`packages/keepa-mcp`) rather than a remote `npx` download.

A companion command, `shopping-research`, chains all three servers into one
"find the best value for product X" workflow (search both markets → judge price
history → check reviews → verify seller → verdict). Run it from opencode with:

```
/shopping-research <product description>
```

## Default Skills

This module includes pre-configured skills for common tasks:

| Skill | Description |
|-------|-------------|
| `git-repo-management` | Git repository management, gitreposync service, common git tasks |
| `nixos-configuration` | Working with this NixOS configuration repository |
| `module-development` | Creating modules following repo conventions |
| `deploy-workflow` | Deploying NixOS via nixos-anywhere, Ventoy USB, and related tools |
| `docker-management` | Docker/Podman containers, Ollama, and OCI tooling |
| `nixos-ensemble-decomposition` | Splitting NixOS work into parallel team slices |
| `opencode-ensemble` | Coordinating ensemble teams, delegating, reviewing teammate output |
| `secrets-management` | Managing agenix-encrypted secrets |
| `testing-patterns` | Writing and running tests |
| `windows-integration` | Windows dual-boot, DSC, unattended installs via Ventoy |

## Usage Example

### Basic Setup

```nix
my.programs.opencode = {
  enable = true;
  model = "anthropic/claude-sonnet-4-20250514";
  anthropic.keyFile = config.age.secrets.anthropic-key.path;
  ollamaModels = flake.config.ollamaModels;
};
```

### With MCP Servers

```nix
my.programs.opencode = {
  enable = true;
  model = "anthropic/claude-sonnet-4-20250514";
  anthropic.keyFile = config.age.secrets.anthropic-key.path;
  
  # MCP servers using uvx (fetched from PyPI)
  mcp = {
    nixos = {
      enabled = true;
      type = "local";
      command = [ "uvx" "mcp-nixos" ];
    };
    nixos-docs = {
      enabled = true;
      type = "local";
      command = [ "uvx" "--from" "mcp-nixos" "mcp-nixos-docs" ];
    };
  };
};
```

### Custom Skills

Add custom skills via the `skills` option:

```nix
my.programs.opencode.skills.my-skill = ''
  # Skill content in Markdown
  # This becomes ~/.config/opencode/skills/my-skill/SKILL.md
  
  ## Overview
  
  Description of what this skill helps with.
  
  ## Common Tasks
  
  - Task 1: How to do it
  - Task 2: Another common pattern
'';
```

Or reference a file:

```nix
my.programs.opencode.skills.my-skill = ./path/to/skill.md;
```

See [OpenCode Skills Documentation](https://opencode.ai/docs/skills/) for the skill format.

### MCP Configuration Format

MCP servers are configured using opencode's native format under the `mcp` key:

| Field | Type | Description |
|-------|------|-------------|
| `enabled` | `boolean` | Whether the server is active |
| `type` | `"local"` or `"remote"` | Server type |
| `command` | `list of string` | Command and arguments to run the server |
| `environment` | `attrsOf string` | (Optional) Environment variables |

See https://opencode.ai/docs/mcp-servers for more details.

## Development Environment

When working with this module locally, no extra env vars are needed — keys are
read from files at runtime via opencode's `{file:...}` substitution or via
`home.sessionVariables` exports.

## Related Modules

No other modules currently import this one.
