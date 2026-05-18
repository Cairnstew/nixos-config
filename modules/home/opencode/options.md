# programs.opencode — Home Manager Options

> Source: https://mynixos.com/home-manager/options/programs.opencode  
> Config schema: https://opencode.ai/docs/config/  
> Providers: https://opencode.ai/docs/providers/  
> Total: 13 options (10 top-level + 3 under `web`)

---

## programs.opencode.enable

**Description:** Whether to enable opencode.  
**Type:** `boolean`  
**Default:** `false`  
**Example:** `true`

---

## programs.opencode.package

**Description:** The opencode package to use.  
**Type:** `null or package`  
**Default:** `pkgs.opencode`

---

## programs.opencode.enableMcpIntegration

**Description:** Whether to integrate the MCP servers config from `programs.mcp.servers` into `programs.opencode.settings.mcp`. Settings defined in `programs.mcp.servers` are merged with `programs.opencode.settings.mcp`, with OpenCode settings taking precedence.  
**Type:** `boolean`  
**Default:** `false`

---

## programs.opencode.settings

**Description:** Configuration written to `$XDG_CONFIG_HOME/opencode/config.json`. Note: `"$schema": "https://opencode.ai/config.json"` is automatically added.

**Type:** `JSON value`  
**Default:** `{ }`

Config files are **merged** (not replaced) across locations. Precedence order (later overrides earlier):
1. Remote config (`.well-known/opencode`)
2. Global config (`~/.config/opencode/opencode.json`)
3. Custom config (`OPENCODE_CONFIG` env var)
4. Project config (`opencode.json` in project root)
5. `.opencode` directories
6. Inline config (`OPENCODE_CONFIG_CONTENT` env var)
7. Managed/admin config files

Variable substitution is supported: `{env:VAR_NAME}` and `{file:path/to/file}`.

### Full settings schema

#### `model`
**Type:** `string`  
The primary model to use. Format: `"provider/model-id"`.  
**Example:** `"anthropic/claude-sonnet-4-5"`

#### `small_model`
**Type:** `string`  
A cheaper model for lightweight tasks like title generation. Falls back to main model if unset.  
**Example:** `"anthropic/claude-haiku-4-5"`

#### `default_agent`
**Type:** `string`  
Default agent to use when none is specified. Must be a primary agent (not a subagent). Can be a built-in (`"build"`, `"plan"`) or custom agent. Falls back to `"build"` if not found.  
**Example:** `"plan"`

#### `shell`
**Type:** `string`  
Shell used for the interactive terminal and agent tool calls. If unset, auto-detects based on OS (e.g. `pwsh`/`cmd.exe` on Windows, `zsh`/`bash` on Linux/macOS).  
**Example:** `"pwsh"`

#### `autoupdate`
**Type:** `boolean | "notify"`  
Controls automatic updates on startup. Set to `false` to disable, `"notify"` to be notified without auto-installing. Only applies if not installed via a package manager.  
**Default:** `true`

#### `snapshot`
**Type:** `boolean`  
Whether to track file changes during agent operations (enables undo/revert). Disable for large repos or projects with many submodules to avoid slow indexing and disk usage.  
**Default:** `true`

#### `share`
**Type:** `"manual" | "auto" | "disabled"`  
Controls session sharing behavior.
- `"manual"` — Share only via explicit `/share` command (default)
- `"auto"` — Automatically share all new conversations
- `"disabled"` — Sharing entirely disabled

#### `instructions`
**Type:** `array of string (paths/globs)`  
Paths and glob patterns to instruction files loaded as context rules for the model.  
**Example:** `["CONTRIBUTING.md", "docs/guidelines.md", ".cursor/rules/*.md"]`

#### `disabled_providers`
**Type:** `array of string`  
Provider IDs to disable even if credentials are available. Takes priority over `enabled_providers`.  
**Example:** `["openai", "gemini"]`

#### `enabled_providers`
**Type:** `array of string`  
Allowlist of provider IDs. When set, only listed providers are enabled. `disabled_providers` still takes priority.  
**Example:** `["anthropic", "openai"]`

#### `plugin`
**Type:** `array of string`  
npm package names of plugins to load.  
**Example:** `["opencode-helicone-session", "@my-org/custom-plugin"]`

#### `experimental`
**Type:** `object`  
Experimental options under active development. Not stable; may change or be removed without notice.

---

#### `server`
Server settings for `opencode serve` / `opencode web`.

| Key | Type | Description |
|-----|------|-------------|
| `port` | `number` | Port to listen on |
| `hostname` | `string` | Hostname to listen on. Defaults to `0.0.0.0` when `mdns` is enabled |
| `mdns` | `boolean` | Enable mDNS service discovery for network device discovery |
| `mdnsDomain` | `string` | Custom mDNS domain name. Defaults to `opencode.local` |
| `cors` | `array of string` | Additional allowed origins for CORS (full origin: scheme + host + port) |

**Example:**
```json
{
  "server": {
    "port": 4096,
    "hostname": "0.0.0.0",
    "mdns": true,
    "mdnsDomain": "myproject.local",
    "cors": ["http://localhost:5173"]
  }
}
```

---

#### `tools`
Control which tools the LLM can use. Map of tool name to `false` to disable.

**Example:**
```json
{
  "tools": {
    "write": false,
    "bash": false
  }
}
```

---

#### `permission`
Default is to allow all operations. Use `"ask"` to require user approval.

**Example:**
```json
{
  "permission": {
    "edit": "ask",
    "bash": "ask"
  }
}
```

---

#### `attachment`
Controls image attachment normalisation before sending to models.

| Key | Type | Description |
|-----|------|-------------|
| `image.auto_resize` | `boolean` | Resize images exceeding limits. Set to `false` to reject instead |
| `image.max_width` | `number` | Max width in pixels before resize/rejection. Default: `2000` |
| `image.max_height` | `number` | Max height in pixels before resize/rejection. Default: `2000` |
| `image.max_base64_bytes` | `number` | Max base64 payload size. Default: `5242880` |

---

#### `compaction`
Controls context window compaction behaviour.

| Key | Type | Description |
|-----|------|-------------|
| `auto` | `boolean` | Automatically compact when context is full. Default: `true` |
| `prune` | `boolean` | Remove old tool outputs to save tokens. Default: `true` |
| `reserved` | `number` | Token buffer for compaction to avoid overflow |

---

#### `watcher`
File watcher configuration.

| Key | Type | Description |
|-----|------|-------------|
| `ignore` | `array of string` | Glob patterns for directories/files to exclude from watching |

**Example:**
```json
{
  "watcher": {
    "ignore": ["node_modules/**", "dist/**", ".git/**"]
  }
}
```

---

#### `formatter`
Enable/configure code formatters. Omit to keep disabled.

- Set to `true` to enable all built-in formatters.
- Or use an object to configure per-formatter overrides.

| Key | Type | Description |
|-----|------|-------------|
| `<name>.disabled` | `boolean` | Disable a specific built-in formatter |
| `<name>.command` | `array of string` | Command array to run, with `$FILE` placeholder |
| `<name>.environment` | `object` | Environment variables for the command |
| `<name>.extensions` | `array of string` | File extensions this formatter applies to |

---

#### `lsp`
Enable/configure LSP servers. Omit to keep disabled.

- Set to `true` to enable all built-in LSP servers.
- Or use an object to configure per-server overrides.

| Key | Type | Description |
|-----|------|-------------|
| `<name>.disabled` | `boolean` | Disable a specific built-in LSP server |

---

#### `mcp`
MCP (Model Context Protocol) server configurations. See https://opencode.ai/docs/mcp-servers.

**Example:**
```json
{
  "mcp": {
    "jira": {
      "type": "remote",
      "url": "https://jira.example.com/mcp",
      "enabled": true
    }
  }
}
```

---

#### `agent`
Define custom agents for specialised tasks.

| Key | Type | Description |
|-----|------|-------------|
| `<name>.description` | `string` | What this agent does |
| `<name>.model` | `string` | Model to use for this agent |
| `<name>.prompt` | `string` | System prompt for the agent |
| `<name>.tools` | `object` | Tool overrides (e.g. `{ "write": false }`) |

**Example:**
```json
{
  "agent": {
    "code-reviewer": {
      "description": "Reviews code for best practices and potential issues",
      "model": "anthropic/claude-sonnet-4-5",
      "prompt": "You are a code reviewer. Focus on security, performance, and maintainability.",
      "tools": {
        "write": false,
        "edit": false
      }
    }
  }
}
```

---

#### `command`
Define custom slash commands for repetitive tasks.

| Key | Type | Description |
|-----|------|-------------|
| `<name>.template` | `string` | Prompt template. Use `$ARGUMENTS` for user-supplied input |
| `<name>.description` | `string` | Description shown in the command list |
| `<name>.agent` | `string` | Which agent to run the command with |
| `<name>.model` | `string` | Override the model for this command |

---

#### `provider`
Configure LLM providers. See the **Provider Reference** section below for the full list.

| Key | Type | Description |
|-----|------|-------------|
| `<id>.options.apiKey` | `string` | API key (supports `{env:VAR}` syntax) |
| `<id>.options.baseURL` | `string` | Custom base URL / endpoint |
| `<id>.options.timeout` | `number` | Request timeout in ms. Default: `300000`. Set to `false` to disable |
| `<id>.options.chunkTimeout` | `number` | Timeout between streamed chunks in ms |
| `<id>.options.setCacheKey` | `boolean` | Always set a cache key for this provider |
| `<id>.options.headers` | `object` | Custom headers sent with every request |
| `<id>.models` | `object` | Model overrides/additions |
| `<id>.npm` | `string` | npm package for custom providers |
| `<id>.name` | `string` | Display name for custom providers |

Model entry shape:
```json
{
  "model-id": {
    "name": "Display Name",
    "id": "actual-model-id-or-arn",
    "limit": {
      "context": 200000,
      "output": 65536
    }
  }
}
```

---

## programs.opencode.tui

**Description:** TUI-specific configuration written to `$XDG_CONFIG_HOME/opencode/tui.json`. Since OpenCode v1.2.15, TUI settings must be in this separate file — `theme`, `keybinds`, and `tui` keys in `settings` are deprecated. Note: `"$schema": "https://opencode.ai/tui.json"` is automatically added.

**Type:** `JSON value`  
**Default:** `{ }`  
**Example:**
```nix
{
  theme = "system";
  keybinds = {
    leader = "alt+b";
  };
  scroll_speed = 3;
  scroll_acceleration = { enabled = true; };
  diff_style = "auto";
  mouse = true;
  attention = {
    enabled = true;
    notifications = true;
    sound = true;
    volume = 0.4;
  };
}
```

---

## programs.opencode.context

**Description:** Global context for OpenCode. Written to `$XDG_CONFIG_HOME/opencode/AGENTS.md`. Can be inline string content or a path to a file.  
**Type:** `strings concatenated with "\n" or absolute path`  
**Default:** `""`

---

## programs.opencode.agents

**Description:** Custom agents. Attribute name becomes the agent filename, creating `opencode/agent/<name>.md`. Can also be a directory path, symlinked to `$XDG_CONFIG_HOME/opencode/agent/`.  
**Type:** `(attribute set of (strings concatenated with "\n" or absolute path)) or absolute path`  
**Default:** `{ }`

---

## programs.opencode.commands

**Description:** Custom slash commands. Attribute name becomes the command filename, creating `opencode/commands/<name>.md`. Can also be a directory path, symlinked to `$XDG_CONFIG_HOME/opencode/commands/`.  
**Type:** `(attribute set of (strings concatenated with "\n" or absolute path)) or absolute path`  
**Default:** `{ }`

---

## programs.opencode.skills

**Description:** Custom skills. Attribute values can be inline string (creates `opencode/skills/<name>/SKILL.md`), a file path, a directory path, or a Nix store path. Directory path is symlinked to `$XDG_CONFIG_HOME/opencode/skills/`. See https://opencode.ai/docs/skills/.  
**Type:** `(attribute set of (strings concatenated with "\n" or absolute path or string)) or absolute path`  
**Default:** `{ }`

---

## programs.opencode.themes

**Description:** Custom themes. Attribute name becomes the theme filename, creating `opencode/themes/<name>.json`. Value can be an attribute set (converted to JSON) or a file path. Directory path is symlinked to `$XDG_CONFIG_HOME/opencode/themes/`. Set `programs.opencode.tui.theme` to activate. See https://opencode.ai/docs/themes/.  
**Type:** `(attribute set of (JSON value or absolute path)) or absolute path`  
**Default:** `{ }`

---

## programs.opencode.tools

**Description:** Custom tools. Attribute name becomes the tool filename, creating `opencode/tools/<name>.ts` or `.js`. Can also be a directory path, symlinked to `$XDG_CONFIG_HOME/opencode/tools/`. See https://opencode.ai/docs/tools/.  
**Type:** `(attribute set of (strings concatenated with "\n" or absolute path)) or absolute path`  
**Default:** `{ }`

---

## programs.opencode.extraPackages

**Description:** Extra packages added to the PATH available to OpenCode.  
**Type:** `list of package`  
**Default:** `[ ]`  
**Example:** `[ pkgs.uv ]`

---

## programs.opencode.web (option-set)

### programs.opencode.web.enable
**Description:** Whether to enable the opencode web service.  
**Type:** `boolean` | **Default:** `false`

### programs.opencode.web.environmentFile
**Description:** Path to a systemd-style `KEY=VALUE` environment file for the web service. Recommended way to set `OPENCODE_SERVER_PASSWORD` without exposing secrets in the Nix store.  
**Type:** `null or absolute path` | **Default:** `null`  
**Example:** `"/run/secrets/opencode-web"`

### programs.opencode.web.extraArgs
**Description:** Extra CLI arguments passed to `opencode serve`. Override server options from the config file.  
**Type:** `list of string` | **Default:** `[ ]`  
**Example:** `[ "--hostname" "0.0.0.0" "--port" "4096" "--mdns" "--cors" "https://example.com" ]`

---

---

# Provider Reference

OpenCode supports 75+ providers via the AI SDK. API keys are stored in `~/.local/share/opencode/auth.json` after running `/connect`. Keys can also be set via environment variables or `provider.<id>.options.apiKey` in config. Variable substitution (`{env:VAR}`, `{file:path}`) is supported.

## First-party / Recommended

| Provider | Config ID | Env Var / Auth | Notes |
|----------|-----------|----------------|-------|
| **OpenCode Zen** | `zen` | API key from opencode.ai/zen | Curated tested models by the OpenCode team |
| **OpenCode Go** | `go` | API key from opencode.ai/zen | Low-cost subscription for popular open coding models |
| **Anthropic** | `anthropic` | `ANTHROPIC_API_KEY` | Claude models. Also supports Claude Pro/Max OAuth |
| **OpenAI** | `openai` | `OPENAI_API_KEY` | Also supports ChatGPT Plus/Pro OAuth |
| **GitHub Copilot** | `github-copilot` | Device-flow OAuth | Some models require Pro+ subscription |
| **GitLab Duo** | `gitlab` | `GITLAB_TOKEN` or OAuth | Premium/Ultimate license required. Experimental |

## Cloud Providers

| Provider | Config ID | Env Var / Auth | Notes |
|----------|-----------|----------------|-------|
| **Amazon Bedrock** | `amazon-bedrock` | `AWS_ACCESS_KEY_ID`+`AWS_SECRET_ACCESS_KEY`, `AWS_PROFILE`, or `AWS_BEARER_TOKEN_BEDROCK` | Config options: `region`, `profile`, `endpoint`. Supports EKS IRSA. Bearer token takes highest precedence |
| **Google Vertex AI** | `google-vertex` | `GOOGLE_APPLICATION_CREDENTIALS` + `GOOGLE_CLOUD_PROJECT` | Also via `gcloud auth application-default login`. Optional: `VERTEX_LOCATION` |
| **Azure OpenAI** | `azure` | `AZURE_RESOURCE_NAME` + API key | Endpoint: `https://RESOURCE_NAME.openai.azure.com/`. Deployment name must match model name |
| **Azure Cognitive Services** | `azure-cognitive-services` | `AZURE_COGNITIVE_SERVICES_RESOURCE_NAME` + API key | Endpoint: `https://RESOURCE_NAME.cognitiveservices.azure.com/` |

## Gateways & Aggregators

| Provider | Config ID | Env Var / Auth | Notes |
|----------|-----------|----------------|-------|
| **OpenRouter** | `openrouter` | API key | 75+ models. Extra models via `provider.openrouter.models` |
| **Cloudflare AI Gateway** | `cloudflare-ai-gateway` | `CLOUDFLARE_ACCOUNT_ID`, `CLOUDFLARE_GATEWAY_ID`, `CLOUDFLARE_API_TOKEN` | Unified billing. Supports Anthropic, OpenAI, Workers AI etc. |
| **Cloudflare Workers AI** | `cloudflare-workers-ai` | `CLOUDFLARE_ACCOUNT_ID`, `CLOUDFLARE_API_KEY` | Models run on Cloudflare's network |
| **Vercel AI Gateway** | `vercel` | API key | List price, no markup. Routing options: `order`, `only`, `zeroDataRetention` |
| **Helicone** | `helicone` | API key | Observability + routing. Custom npm block required for extra models. Supports `Helicone-Cache-Enabled`, `Helicone-User-Id`, session tracking headers |
| **LLM Gateway** | `llmgateway` | API key | — |
| **ZenMux** | `zenmux` | API key | — |
| **302.AI** | `302ai` | API key | — |

## Inference Providers

| Provider | Config ID | Env Var / Auth | Notes |
|----------|-----------|----------------|-------|
| **DeepSeek** | `deepseek` | API key | DeepSeek V4 Pro etc. |
| **Groq** | `groq` | API key | — |
| **Fireworks AI** | `fireworks` | API key | Kimi K2 Instruct etc. |
| **Together AI** | `together` | API key | Kimi K2 Instruct etc. |
| **Cerebras** | `cerebras` | API key | Qwen 3 Coder 480B etc. |
| **Hugging Face** | `huggingface` | API key | 17+ inference providers |
| **Moonshot AI** | `moonshot` | API key | Kimi K2 |
| **MiniMax** | `minimax` | API key | M2.1 etc. |
| **xAI** | `xai` | API key | Grok Beta etc. |
| **NVIDIA** | `nvidia` | `NVIDIA_API_KEY` | Nemotron + open models. On-prem NIM via `baseURL` |
| **Deep Infra** | `deepinfra` | API key | — |
| **Baseten** | `baseten` | API key | — |
| **IO.NET** | `ionet` | API key | 17 models |
| **Cortecs** | `cortecs` | API key | Kimi K2 Instruct etc. |
| **Nebius Token Factory** | `nebius` | API key | Kimi K2 Instruct etc. |
| **Venice AI** | `venice` | API key | Llama 3.3 70B etc. |
| **FrogBot** | `frogbot` | API key | — |
| **DigitalOcean** | `digitalocean` | `DIGITALOCEAN_ACCESS_TOKEN` or OAuth | Supports Inference Routers (`router:<name>`) |
| **Scaleway** | `scaleway` | API key | European infrastructure |
| **OVHcloud AI Endpoints** | `ovhcloud` | API key | — |
| **STACKIT** | `stackit` | API key | Sovereign EU hosting |
| **SAP AI Core** | `sap-ai-core` | `AICORE_SERVICE_KEY` (JSON) | 40+ models. Optional: `AICORE_DEPLOYMENT_ID`, `AICORE_RESOURCE_GROUP` |
| **Z.AI** | `zai` | API key | GLM-4.7 etc. |

## Local Models

| Provider | Config approach | Default base URL | Notes |
|----------|----------------|------------------|-------|
| **Ollama** | Custom provider block | `http://localhost:11434/v1` | npm: `@ai-sdk/openai-compatible`. Ollama can auto-configure via its integration |
| **Ollama Cloud** | `/connect` → Ollama Cloud | — | Must `ollama pull <model>` locally first |
| **LM Studio** | Custom provider block | `http://127.0.0.1:1234/v1` | npm: `@ai-sdk/openai-compatible` |
| **llama.cpp** | Custom provider block | `http://127.0.0.1:8080/v1` | npm: `@ai-sdk/openai-compatible` |
| **Atomic Chat** | Custom provider block | `http://127.0.0.1:1337/v1` | npm: `@ai-sdk/openai-compatible`. Desktop app |

## Custom / OpenAI-Compatible Provider

Any provider with an OpenAI-compatible API:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "provider": {
    "myprovider": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "My Provider Display Name",
      "options": {
        "baseURL": "https://api.myprovider.com/v1",
        "apiKey": "{env:MY_API_KEY}",
        "headers": {
          "Authorization": "Bearer custom-token"
        }
      },
      "models": {
        "my-model": {
          "name": "My Model Display Name",
          "limit": {
            "context": 200000,
            "output": 65536
          }
        }
      }
    }
  }
}
```

Notes:
- Use `@ai-sdk/openai-compatible` for `/v1/chat/completions` endpoints.
- Use `@ai-sdk/openai` for `/v1/responses` endpoints.
- Per-model `npm` override is possible for mixed setups.
- Provider ID used in `/connect` must match the key in `provider` config.
- Credentials are stored in `~/.local/share/opencode/auth.json`.

## Amazon Bedrock — Authentication Precedence

1. Bearer token (`AWS_BEARER_TOKEN_BEDROCK` env var or from `/connect`) — highest priority
2. AWS credential chain: named profile, access keys, shared credentials, IAM roles, Web Identity Tokens (EKS IRSA), EC2 instance metadata

When a bearer token is set, it overrides all other AWS credential methods including configured profiles.