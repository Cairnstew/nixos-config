# Open WebUI

Self-hosted AI platform with MCP support, persistent memory, RAG, image generation, and Ollama backend integration.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `my.services.open-webui.enable` | `false` | Enable Open WebUI |
| `my.services.open-webui.port` | `3000` | Web UI port |
| `my.services.open-webui.backend` | `"docker"` | OCI backend |
| `my.services.open-webui.ollama.enable` | `false` | Auto-configure Ollama endpoint |
| `my.services.open-webui.webSearch.enable` | `false` | Enable web search for RAG |
| See options.nix for full list | | |

## Usage

```nix
my.services.open-webui = {
  enable = true;
  ollama.enable = true;
  webSearch.enable = true;
};
```
