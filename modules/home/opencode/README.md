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

## Default Skills

This module includes pre-configured skills for common tasks:

| Skill | Description |
|-------|-------------|
| `git-repo-management` | Git repository management, gitreposync service, common git tasks |
| `nixos-configuration` | Working with this NixOS configuration repository |
| `module-development` | Creating modules following repo conventions |

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
