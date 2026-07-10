# RisuAI

LLM roleplay frontend as an OCI container with HypaMemory/SupaMemory, MCP support, and Ollama backend integration.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `my.services.risuai.enable` | `false` | Enable RisuAI |
| `my.services.risuai.port` | `6001` | Web UI port |
| `my.services.risuai.backend` | `"docker"` | OCI backend |
| `my.services.risuai.ollama.enable` | `false` | Auto-configure Ollama endpoint |
| See options.nix for full list | | |

## Usage

```nix
my.services.risuai = {
  enable = true;
  ollama.enable = true;
};
```
