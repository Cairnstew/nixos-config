# Jan

Open-source ChatGPT alternative with local LLM inference, MCP support, and Ollama integration.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `my.services.jan.enable` | `false` | Enable Jan (desktop app + optional API server) |
| `my.services.jan.apiServer.enable` | `false` | Enable OpenAI-compatible API server |
| `my.services.jan.apiServer.port` | `1337` | API server port |
| `my.services.jan.ollama.enable` | `false` | Auto-configure Ollama as model source |
| See options.nix for full list | | |

## Usage

```nix
my.services.jan = {
  enable = true;
  ollama.enable = true;
};

# With API server:
my.services.jan = {
  enable = true;
  apiServer.enable = true;
  ollama.enable = true;
};
```
