# SillyTavern

LLM frontend with Ollama integration, declarative presets, and basic auth.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `my.services.sillytavern.enable` | `false` | Enable SillyTavern |
| `my.services.sillytavern.port` | `8000` | Listen port |
| `my.services.sillytavern.ollama.enable` | `false` | Auto-configure Ollama connection |

## Usage

```nix
my.services.sillytavern = {
  enable = true;
  ollama.enable = true;
};
```
