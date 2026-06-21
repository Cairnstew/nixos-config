# SillyTavern

LLM frontend with Ollama integration, declarative presets, and basic auth.

## Options

| Option | Type | Description |
|--------|------|-------------|
| `enable` | bool | Enable SillyTavern |
| `port` | int | Listen port (default: 8000) |
| `ollama.enable` | bool | Auto-configure Ollama connection |
| `ollama.models` | attrset | Multi-model connection profiles (auto-wires to ollama) |
| `personas` | attrset | User personas (`{name, avatar?, description?}`) |

### Presets

| Option | Directory | Description |
|--------|-----------|-------------|
| `presets.instruct` | `instruct/` | Instruct templates (38 built-in) |
| `presets.context` | `context/` | Context templates (34 built-in) |
| `presets.sysprompt` | `sysprompt/` | System prompts (13 built-in) |
| `presets.textgen` | `TextGen Settings/` | TextGen sampler presets (6 built-in) |
| `presets.reasoning` | `reasoning/` | Reasoning templates (prefix/suffix) |
| `presets.kobold` | `Kobold AI Settings/` | KoboldAI sampler presets |
| `presets.openai` | `OpenAI Settings/` | OpenAI/chat completion presets |
| `presets.themes` | `themes/` | UI themes |
| `presets.quickReplies` | `quick-replies/` | Quick reply button presets |

### Settings (via `SILLYTAVERN_*` env vars)

| Option | Description |
|--------|-------------|
| `settings.ssl.enable` | SSL/TLS encryption |
| `settings.logging.minLogLevel` | 0=DEBUG, 1=INFO, 2=WARN, 3=ERROR |
| `settings.enableUserAccounts` | Multi-user mode |
| `settings.performance.lazyLoadCharacters` | Lazy load character cards |
| `settings.ollama.keepAlive` | Model keep-alive time (-1=forever) |

## Usage

```nix
my.services.sillytavern = {
  enable = true;
  ollama = {
    enable = true;
    models = {
      "hf.co/Lewdiculous/InfinityRP-v1-7B-GGUF-IQ-Imatrix:Q4_K_M" = {
        preset = "Roleplay";
        sysprompt = "Creative Writing";
        numCtx = 8192;
        temperature = 0.9;
      };
    };
  };
  personas.my-default = {
    name = "Sean";
    description = "A curious explorer.";
  };
  presets.themes.my-dark = {
    main_text_color = "rgba(220, 220, 210, 1)";
    blur_strength = 10;
    font_scale = 1.1;
  };
  settings = {
    enableUserAccounts = true;
    logging.minLogLevel = 1;
  };
};
```

## Notes

- Settings injected as `SILLYTAVERN_*` env vars, override `config.yaml`
- Preset files written on each activation (service start)
- Models auto-populate `my.services.ollama.models` and auto-pull
- L2 smoke test: `systemctl start sillytavern-smoke-test`
