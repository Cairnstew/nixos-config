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
| `my.programs.opencode.modelFallback.cacheFile` | `~/.cache/opencode/go-usage.json` | Usage snapshot consumed by the selector |
| `my.programs.opencode.modelFallback.sliceFile` | `~/.cache/opencode/go-usage-slices.json` | Budget-pacing slice snapshot (written by usage.nix) |
| `my.programs.opencode.modelFallback.repoDir` | `~/nixos-config` | Repo whose project-level ensemble override receives resolved models |

Chain entries additionally accept a `pacing` block (`mode`,
`budget.windows`, `budget.sliceHours`, `floor`, `buffer`) — see
[Pace-based caps](#pace-based-caps-weeklymonthly-only) and
[Budget pacing](#budget-pacing-pacingmode--budget-monthly-only-by-default) below.

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
  weekly = `resetsAt − 7d` (**exact**; calendar-aligned Monday 00:00 UTC —
  rollover observed verbatim at `2026-08-31T00:00:00Z`); monthly =
  `resetsAt − 30d` (**exact** — a fixed 30-day window anchored at
  `2026-09-20T09:25:34Z`, not the ±1 day approximation previously feared;
  the weekly rollover and the monthly reset have both been observed).
  Re-confirm at the 2026-10-20 reset; next expected `2026-11-19T09:25:34Z`.
- Rolling is **excluded**: it is a trailing 5-hour *sliding* window
  (`resetsAt = now + 5h` on every poll — nine samples across two days), so it
  has no anchor to pace against. Entries setting `pacing.enable` must
  constrain `maxWeeklyPercent` or `maxMonthlyPercent`; this is asserted in
  `tests.nix` and throws at eval otherwise.

### Budget pacing (`pacing.mode = "budget"`, monthly only by default)

While *elapsed* pacing grows the cap with calendar time, **budget** pacing
divides what is *left* of a fixed window by the time left, in slices:

```
sliceCap = usageAtStart + (100 − usageAtStart) / slicesLeft
slicesLeft = ceil((resetsAt − sliceStart) / sliceHours)
```

`usageAtStart` is the usage percent recorded at the start of the current
slice; `sliceStart` is when that slice began. A new slice starts every
`sliceHours` (default 24h) and at every monthly reset, seeded with the usage
percent at that moment. Example: 40% of the month already spent with 21 days
left → `slicesLeft ≈ 21`, `sliceCap ≈ 43.3%` for the day — about 1.9%/day.

Unspent budget rolls forward each slice (the next slice re-seeds from actual
usage), and overspend is spread over the remaining slices rather than causing
a lockout followed by a full-rate resume. The effective cap is
`min(maxMonthlyPercent, sliceCap)` — the static monthly backstop always wins.

**Snapshot file:** usage.nix writes `~/.cache/opencode/go-usage-slices.json`
(shape `{"monthly": {"sliceStart": <epoch>, "usageAtStart": <pct>,
"resetsAt": "<iso>"}}`) atomically on every poll; a new snapshot starts when
none exists, when the slice has elapsed, or when the cache's `resetsAt`
differs from the snapshot's (period reset).

**Degrade rules (never an error):** budget pacing is skipped for a window and
only static caps apply when the snapshot is missing, its `resetsAt` disagrees
with the cache, or it is older than 2 slices (the 5-minute refresher has been
down). A malformed snapshot is treated the same way from inside
`model-select.jq` (`try … catch null`).

**Why monthly only:** budget math needs a fixed, known window length. The
monthly window is a fixed 30-day period (anchored `2026-09-20T09:25:34Z`);
rolling is a trailing 5h sliding window (no anchor), and weekly is
use-it-or-lose-it — both stay on static ceilings. Weekly can be added to
`pacing.budget.windows` later using the same math with its own slice length.

**Why elapsed pacing ships disabled:** the current chains do not enable
*elapsed* pacing. The monthly window is instead guarded two ways: a fixed
`maxMonthlyPercent` backstop on every rung, and — on the lead rung of the
default chain — **budget** pacing (`pacing.mode = "budget"`, see above),
which is strictly better for a fixed 30-day window than elapsed pacing. The
evidence gates that used to block shipping pacing are confirmed: weekly
rollover observed verbatim (`weekly.resetsAt = 2026-08-31T00:00:00Z`), and the
monthly reset confirmed a fixed 30-day window anchored at
`2026-09-20T09:25:34Z` (re-confirm at the 2026-10-20 reset, next expected
`2026-11-19T09:25:34Z`).

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

A chain whose LAST entry is `{ blockedTerminal = true; }` (no `model`) resolves to
a distinguishable **BLOCKED** outcome — the selector prints a stderr reason and
exits **5** — instead of silently falling to an always-eligible free model. The
`default` chain ends in a cap-free model (`opencode-go/ox-alpha-free`) so ordinary
build/explore work never blocks. The **triage chains are live** in
`modules/nixos/homeManager/config.nix` (`learning-promoter`, `scout-skeptical`,
`qa-verification`, `adversarial`): they give scout/qa/reviewer subagents tighter
caps than the default chain and end in `blockedTerminal`, so a triage chain that
exhausts surfaces as **BLOCKED** (selector exit 5) instead of silently degrading
to a free-tier model.

### Known limits — self-improvement is model-chain-independent

The single-lineage self-improvement checkpoint runs in-band on `build`/`researcher`
and has no dedicated watcher, queue, or `opencode serve` dependency — the in-band
checkpoint itself needs no model protection. `modelFallback` governs the
interactive `default` chain and the triage chains
(`scout-skeptical`/`qa-verification`/`adversarial`/`learning-promoter`) that
scout/verify/review ensemble work: the triage chains carry the tightest caps and
end in `blockedTerminal`, so an exhausted triage chain pauses its dispatch instead
of running a degraded model.

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
