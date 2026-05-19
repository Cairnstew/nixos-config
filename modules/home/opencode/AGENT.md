# modules/home/opencode/AGENT.md

> **Scope:** OpenCode AI coding agent configuration
> **Module:** `my.programs.opencode`

---

## Module Purpose

Configures [OpenCode](https://opencode.ai), an AI coding agent for the terminal,
with support for 15+ LLM providers and custom skills, tools, and agents.

---

## Directory Structure

```
modules/home/opencode/
├── default.nix      # Import manifest
├── meta.nix         # Machine-readable metadata
├── options.nix      # Option declarations (my.programs.opencode.*)
├── config.nix       # Main implementation
├── providers.nix    # LLM provider configuration logic
├── providers.md     # Provider documentation
├── tests.nix        # Module tests
├── README.md        # Human documentation
└── AGENT.md         # This file
```

---

## Key Options

| Option | Purpose |
|--------|---------|
| `enable` | Enable opencode |
| `model` | Default model (provider/model-id) |
| `*.keyFile` | API key files for cloud providers |
| `ollamaModels` | Local Ollama models to register |
| `skills` | Custom skills for opencode |
| `tools` | Custom tools for opencode |
| `agents` | Custom agent configurations |
| `mcp` | MCP server configurations |

---

## Skills System

Skills provide context-aware instructions to opencode for specific tasks.
They are stored in `$XDG_CONFIG_HOME/opencode/skills/<name>/SKILL.md`.

### Available Skills

| Skill | Description |
|-------|-------------|
| `git-repo-management` | Git repository management patterns, gitreposync service |

### Adding New Skills

Add skills via the `my.programs.opencode.skills` option:

```nix
my.programs.opencode.skills.my-skill = ''
  # SKILL.md content here
  # Describe patterns, conventions, and tasks
'';
```

Skills should follow the [OpenCode skills documentation](https://opencode.ai/docs/skills/).

---

## Provider Categories

### SDK-based (env-var keys)
- OpenAI, Anthropic, Google, Groq, Mistral, xAI, DeepInfra

### OpenAI-compatible (file substitution)
- Together, OpenRouter, Fireworks, Cerebras, Clarifai

### First-class (auth.json only)
- OpenCode Go, OpenCode Zen

### Local
- Ollama

---

## Integration Points

- **agenix**: API keys read from age-encrypted secrets
- **home-manager**: User environment and config files
- **MCP**: Model Context Protocol servers for extended capabilities

---

## Conventions

1. **Never commit API keys**: Always use `keyFile` options with agenix
2. **Prefer local models**: Ollama for privacy-sensitive work
3. **Use skills for repo patterns**: Document conventions in skills
4. **Agent permissions**: Restrict `plan`/`explore` agents, allow `build`

---

## See Also

- `modules/nixos/gitreposync/` - Git repository sync service
- `modules/home/core/git.nix` - Git configuration
- [OpenCode Docs](https://opencode.ai/docs/)
