# OpenCode Providers

> Reference: https://opencode.ai/docs/providers

OpenCode supports 75+ LLM providers via the [AI SDK](https://ai-sdk.dev/) and
[Models.dev](https://models.dev). This module handles provider configuration
for NixOS/home-manager users.

---

## How Provider Auth Works

Per the [official docs](https://opencode.ai/docs/providers#credentials):

> When you add a provider's API keys with the `/connect` command, they are
> stored in `~/.local/share/opencode/auth.json`.

This module writes credentials to `auth.json` at activation time using agenix
secrets, replicating what `/connect` would do interactively.

**To verify auth is working:**
```
opencode auth list
```

---

## Provider Types

There are two distinct types of providers. Mixing them up is a common source
of bugs — see [Troubleshooting](#troubleshooting) below.

### 1. First-Class Providers (auth.json only)

These are natively supported by OpenCode. Their credentials go **only** in
`~/.local/share/opencode/auth.json` and must **NOT** appear in `opencode.json`'s
`provider` block.

| Provider        | Module Option                          |
|----------------|----------------------------------------|
| OpenCode Go    | `opencode-go.keyFile`                  |
| OpenCode Zen   | `opencode-zen.keyFile`                 |
| Anthropic      | `anthropic.keyFile`                    |
| Groq           | `groq.keyFile`                         |
| OpenAI         | `openai.keyFile`                       |
| Google         | `google.keyFile`                       |
| Mistral        | `mistral.keyFile`                      |
| xAI            | `xai.keyFile`                          |

> Docs: https://opencode.ai/docs/providers#opencode-go

### 2. Custom / OpenAI-Compatible Providers (opencode.json provider block + auth.json)

These are configured via the `provider` section in `opencode.json` using the
`@ai-sdk/openai-compatible` npm package. They also need a credential in
`auth.json` (keyed by their provider ID), but their endpoint and model list
must be declared in `opencode.json`.

| Provider   | Module Option          | npm package                    |
|-----------|------------------------|--------------------------------|
| DeepInfra  | `deepinfra.keyFile`    | `@ai-sdk/openai-compatible`    |
| Clarifai   | `clarifai.patFile`     | `@ai-sdk/openai-compatible`    |
| Together   | `together.keyFile`     | `@ai-sdk/openai-compatible`    |
| Fireworks  | `fireworks.keyFile`    | `@ai-sdk/openai-compatible`    |
| Cerebras   | `cerebras.keyFile`     | `@ai-sdk/openai-compatible`    |
| OpenRouter | `openrouter.keyFile`   | `@ai-sdk/openai-compatible`    |
| Azure      | `azure.keyFile`        | `@ai-sdk/azure`                |

**Correct baseURL format** (the AI SDK appends `/chat/completions` itself):

```
deepinfra  → https://api.deepinfra.com/v1/openai
clarifai   → https://api.clarifai.com/v2/ext/openai/v1
together   → https://api.together.xyz/v1
fireworks  → https://api.fireworks.ai/inference/v1
cerebras   → https://api.cerebras.ai/v1
openrouter → https://openrouter.ai/api/v1
```

> ⚠️ Do NOT include `/chat/completions` in baseURL — it will cause 404s.

> Docs: https://opencode.ai/docs/providers#custom-provider

---

## OpenCode Go — Special Notes

OpenCode Go is a **first-class provider** (like Zen), not a custom provider.

> https://opencode.ai/docs/go

- Uses model IDs prefixed with `opencode-go/`, e.g. `opencode-go/kimi-k2.5`
- Auth goes in `auth.json` only — no `provider` block in `opencode.json`
- The module writes the key from `config.age.secrets."opencode-token".path`
  to `~/.local/share/opencode/auth.json` under the `opencode-go` key

**Available models (as of May 2026):**

| Model ID                        | Notes                        |
|--------------------------------|------------------------------|
| `opencode-go/kimi-k2.5`        | Primary coding/agentic model |
| `opencode-go/kimi-k2.6`        | Harder tasks                 |
| `opencode-go/qwen3.5-plus`     | Cheap planner / cheap tasks  |
| `opencode-go/qwen3.6-plus`     | —                            |
| `opencode-go/deepseek-v4-flash`| Very cheap, high quota       |
| `opencode-go/deepseek-v4-pro`  | —                            |
| `opencode-go/mimo-v2.5`        | —                            |
| `opencode-go/mimo-v2.5-pro`    | —                            |
| `opencode-go/minimax-m2.5`     | —                            |
| `opencode-go/minimax-m2.7`     | —                            |
| `opencode-go/glm-5`            | —                            |
| `opencode-go/glm-5.1`          | —                            |

> Full model list: https://opencode.ai/docs/go

---

## Module Options Reference

```nix
my.programs.opencode = {
  enable = true;

  # Active model (provider/model-id format)
  model = "opencode-go/kimi-k2.5";

  # First-class providers — written to auth.json only (no provider block)
  opencode-go.keyFile  = config.age.secrets."opencode-token".path;
  anthropic.keyFile    = config.age.secrets.anthropic-key.path;
  groq.keyFile         = config.age.secrets.groq-key.path;

  # OpenAI-compatible providers — written to BOTH auth.json AND opencode.json
  deepinfra.keyFile    = config.age.secrets.deepinfra-key.path;
  clarifai.patFile     = config.age.secrets.clarifai-pat.path;

  # MCP servers
  mcp = {
    nixos = {
      enabled = true;
      type    = "local";
      command = [ "nix" "run" "github:utensils/mcp-nixos" "--" ];
    };
  };
};
```

> **Note:** All providers configured with `keyFile` are automatically written to
> `~/.local/share/opencode/auth.json` at activation time. The module merges with
> existing entries, so providers configured via `/connect` are preserved.

---

## auth.json Format

Written to `~/.local/share/opencode/auth.json`. The module merges entries
rather than overwriting, so multiple providers coexist safely.

All providers use the same format that `/connect` writes:

```json
{
  "opencode-go": {
    "type": "api",
    "key": "<token>"
  },
  "deepinfra": {
    "type": "api",
    "key": "<token>"
  }
}
```

---

## Troubleshooting

> Reference: https://opencode.ai/docs/providers#troubleshooting

**"Not found" or 404 errors on OpenCode Go / Zen:**
- These are first-class providers. Make sure they are NOT in `opencode.json`'s
  `provider` block. Remove any such entry and check `auth.json` instead.
- Run `opencode auth list` to confirm the credential is present.

**Auth not working after nixos-rebuild:**
- The activation script may not have run. Try `home-manager switch` explicitly.
- Check `~/.local/share/opencode/auth.json` exists and contains the key.

**MCP server failing:**
- Use `nix run github:utensils/mcp-nixos --` rather than uvx — uvx may not
  be on PATH when opencode launches in a NixOS environment.
- Check `type = "local"` is set and `command` is a list, not a string.

**Custom provider models not appearing:**
- Run `/models` in the TUI after config changes.
- Confirm the provider ID in `opencode.json` matches the ID used in `/connect`.
- Confirm `baseURL` ends at the version segment (e.g. `/v1`), not at
  `/chat/completions`.