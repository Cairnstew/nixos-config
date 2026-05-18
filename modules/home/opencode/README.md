# Opencode — AI Coding Agent

Home-manager module for [opencode](https://opencode.ai), an AI coding agent for
the terminal, with support for 14+ LLM providers.

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

## Usage Example

```nix
my.programs.opencode = {
  enable = true;
  model = "anthropic/claude-sonnet-4-20250514";
  anthropic.keyFile = config.age.secrets.anthropic-key.path;
  ollamaModels = flake.config.ollamaModels;
};
```

## Development Environment

When working with this module locally, no extra env vars are needed — keys are
read from files at runtime via opencode's `{file:...}` substitution or via
`home.sessionVariables` exports.
