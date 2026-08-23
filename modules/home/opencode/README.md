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

### Example

```nix
my.programs.opencode.modelFallback = {
  enable = true;
  chains.default = [
    { model = "opencode-go/deepseek-v4-flash"; maxWeeklyPercent = 80; }
    { model = "opencode-go/mimo-v2.5"; maxWeeklyPercent = 95; }
    { model = "opencode-go/ox-alpha-free"; }          # safety net, no caps
  ];
  # High-usage-risk agents get tighter caps:
  chains."scout-skeptical" = [
    { model = "opencode-go/deepseek-v4-flash"; maxRollingPercent = 40; maxWeeklyPercent = 60; }
    { model = "opencode-go/mimo-v2.5"; }
  ];
};
```

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
