# Letta (formerly MemGPT)

Stateful AI agent platform with advanced persistent memory, self-improving agents, and Ollama backend support.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `my.services.letta.enable` | `false` | Enable Letta API server |
| `my.services.letta.port` | `8283` | API port |
| `my.services.letta.backend` | `"docker"` | OCI backend |
| `my.services.letta.ollama.enable` | `false` | Auto-configure Ollama as LLM backend |
| `my.services.letta.database.type` | `"sqlite"` | Database backend (sqlite or postgres) |
| See options.nix for full list | | |

## Usage

```nix
my.services.letta = {
  enable = true;
  ollama = {
    enable = true;
    defaultModel = "llama3.2:3b";
  };
};
```
