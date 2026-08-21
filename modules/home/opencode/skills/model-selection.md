# Model Selection (OpenCode Go & LLM cost-effectiveness)

> Skill for looking up LLM models by pricing, usage limits, and capabilities —
> especially OpenCode Go — and picking the most cost-effective model for a task.

## When to use

- A user asks "what's the cheapest model for X?", "which model should I use?",
  "compare model pricing", or "is there a cheaper model that can do Y?"
- You're about to switch `my.programs.opencode.model` (or an agent's `model`)
  and want to compare candidates before editing config.
- You need a model with a specific capability (vision, tool calling, big
  context window, structured output) and want the cheapest option that has it.

## Data source (live, authoritative)

`models.dev` is the catalog that powers OpenCode's own `/models` browser and the
https://opencode.ai/go page. Its single JSON endpoint lists every provider and
model with **per-1M-token pricing**, **context/output limits**, and **capability
flags**. This is the same data OpenCode shows — do not hardcode a static list.

The lookup tool fetches this (cached ~12h under `~/.cache/opencode/`).

## How to look up models

### Via the `opencode-models` tool (inside opencode)

Call the `opencode-models` tool. It defaults to the `opencode-go` provider.

- `action=list` (default) — a table ranked by **blend cost** (cheapest first).
- `action=info`, `model=<id>` — full detail for one model.
- `capability=tools|vision|multimodal|pdf|audio|reasoning|structured|weights|interleaved`
  — require a capability.
- `minContext=<tokens>` / `minOutput=<tokens>` — floor on context/output limits.
- `maxInput/maxOutput/maxCache=<usd>` — ceiling on per-1M-token price.
- `provider=all` — rank across the whole catalog, not just Go.
- `sort=input|output|cache|context|out` — sort by a single column instead of blend.

### Via the CLI (outside opencode)

```bash
nix run .#opencode-models                      # opencode-go, cheapest first
nix run .#opencode-models -- --provider all --top 20
nix run .#opencode-models -- -c vision -c tools --min-context 200000
nix run .#opencode-models -- --info deepseek-v4-flash
nix run .#opencode-models -- --help
```

`--refresh` bypasses the cache when you suspect the data is stale.

## Reading the output

Columns: `$IN` / `$OUT` / `$CACHE` are **USD per 1M tokens**; `CTX` is the
context window; `OUT` the max output tokens; `CAPS` the capability flags.

- **`blend`** = weighted `input + cache_read + output` price (default weights
  `1×in + 5×cache + 1×out`). `cache_read` is weighted 5× because agentic coding
  reuses huge cached context (the Go docs' own request profile is ~50k cached vs
  ~500 fresh input tokens per request), so a low `cache_read` is what actually
  keeps a long session cheap.
- **A low `$CACHE`** is the single best signal for cost-effective agent work.
  E.g. `mimo-v2.5` ($0.0028/M cache) and `muse-spark-1.2-contributor`
  ($0.002/M) are dramatically cheaper per long session than `kimi-k3`
  ($0.30/M) or `grok-4.5`.
- **`CTX`** matters for big repos: `deepseek-v4-flash` and `mimo-v2.5` expose a
  1.0M context, `kimi-k2.6` only ~262K.
- **`OUT`** matters for large diffs: `deepseek-v4-flash`/`-pro` output up to
  384K tokens; most others cap at 64–131K.

## Picking a cost-effective model

Typical choices (verify with the tool — the list rotates):

| Need | Good cheap option | Why |
|------|-------------------|-----|
| Default everyday coding | `opencode-go/deepseek-v4-flash` | 1M ctx, 384K out, $0.007 cache |
| Cheapest long-agent session | `opencode-go/mimo-v2.5` | $0.0028/M cache, 1M ctx |
| Vision/multimodal | `opencode-go/mimo-v2.5` or `muse-spark-1.2-contributor` | cheap + vision |
| Hard reasoning | `opencode-go/deepseek-v4-pro` | stronger, still $0.022 cache |

Set it with the `opencode-go/<model-id>` prefix:

```nix
my.programs.opencode.model = "opencode-go/deepseek-v4-flash";
```

## OpenCode Go economics (context for "cost")

Go is a **flat subscription**, not metered per token: **$5 first month, then
$10/month**, with usage allowances of **$12 per 5 hours, $30/week, $60/month**
(dollar-value limits, so cheaper models stretch further). The request-count
breakdown and per-model "usage multiplier" live on https://opencode.ai/docs/go
and change as models are added — re-check there rather than trusting a cached
number. For per-token prices, always use `models.dev` via this tool.

## Conventions

- Model IDs in config are always prefixed `opencode-go/` (e.g.
  `opencode-go/deepseek-v4-flash`) — see `modules/home/opencode/providers.md`.
- `models.dev` can drift from the static `/docs/go` page (they update at
  different cadences); trust `models.dev` for per-token prices, `/docs/go` for
  subscription limits.
- If `opencode-models` reports a model but opencode says "not found", run
  `/models` in the TUI to refresh the local model list.
