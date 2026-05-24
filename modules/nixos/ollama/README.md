# Ollama

Ollama LLM inference server as an OCI container with model management, MCP integration, and GPU support.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `my.services.ollama.enable` | `false` | Enable Ollama |
| `my.services.ollama.port` | `11434` | API port |
| `my.services.ollama.backend` | `"docker"` | OCI backend |
| `my.services.ollama.gpu.enable` | `false` | GPU passthrough |
| `my.services.ollama.mcp.enable` | `false` | MCP server for Cline |
| See options.nix for full list | | |

## Usage

```nix
my.services.ollama = {
  enable = true;
  gpu.enable = true;
};
```
