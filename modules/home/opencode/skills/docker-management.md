# Docker Management

> Skill for managing Docker/Podman containers, Ollama, and OCI tooling in this NixOS config

## Overview

Docker is managed via `my.virtualisation.docker` options. The system also runs
Ollama in Docker (Ollama OCI containers) and supports GPU passthrough.

## Docker Configuration

### Basic Enablement
```nix
my.virtualisation.docker.enable = true;
```

### Options Reference

| Option | Default | Description |
|--------|---------|-------------|
| `enableOnBoot` | `true` | Start Docker daemon on boot |
| `enableNvidiaContainerToolkit` | `false` | NVIDIA container GPU support |
| `package` | `pkgs.docker` | Docker package |
| `extraOptions` | `""` | Extra daemon options |
| `listenOptions` | `["/run/docker.sock"]` | Listen addresses |
| `liveRestore` | `true` | Keep containers running on restart |
| `logDriver` | `"journald"` | Logging driver |
| `storageDriver` | `null` | Storage driver (auto-detected) |
| `autoPrune.enable` | `false` | Periodic cleanup |
| `dataRoot` | `null` | Custom data directory |
| `rootless.enable` | `false` | Rootless mode |

### Custom Data Directory
```nix
my.virtualisation.docker.dataRoot = "/mnt/docker";
```

Useful when the root partition is small. The desktop has a dedicated 500GB SATA SSD
at `/mnt/docker` for Docker data.

### NVIDIA GPU Passthrough
```nix
my.virtualisation.docker = {
  enable = true;
  enableNvidiaContainerToolkit = true;
};
```

## Ollama (LLM Service in Docker)

Ollama runs as a Docker container managed via `my.services.ollama`.

### Basic Setup
```nix
my.services.ollama = {
  enable = true;
  models = {
    "qwen3.5:9b" = {
      tools = true;
      numCtx = 32768;
      opencode_default = true;
    };
  };
};
```

### GPU Acceleration
```nix
my.services.ollama = {
  enable = true;
  gpu = {
    enable = true;
    type = "nvidia";  # or "amd", "intel"
  };
};
```

### MCP Integration
Ollama can expose an MCP server for AI coding tools:
```nix
my.services.ollama.mcp = {
  enable = true;
  port = 3100;
};
```

### OpenCode Integration
Register Ollama models as opencode providers:
```nix
my.programs.opencode.ollamaModels = {
  "qwen3.5:9b" = {
    name = "qwen3.5:9b";
    tools = true;
    numCtx = 32768;
    opencode_default = true;  # Makes this the default model
  };
};
my.programs.opencode.ollamaBaseURL = "http://127.0.0.1:11434/v1";
```

## Common Tasks

### Check Docker Status
```bash
systemctl status docker
docker info
docker ps
```

### Prune Old Data
```bash
# Manual
docker system prune -af --volumes

# Auto (via Nix option)
my.virtualisation.docker.autoPrune.enable = true;
```

### Inspect Container Logs
```bash
docker logs <container-name>
docker logs -f <container-name>  # Follow
```

### Rebuild and Restart Ollama
```bash
nixos-rebuild switch  # Systemd restarts the container
docker ps | grep ollama
```

## Troubleshooting

### Docker socket permission denied
Ensure the user is in the `docker` group. This is handled automatically by
`my.virtualisation.docker.users` in the common module:
```nix
my.virtualisation.docker.users = [ flake.config.me.username ];
```

### NVIDIA Container Toolkit not working
Verify: `nvidia-smi` works on host, and `enableNvidiaContainerToolkit = true`.
Test with: `docker run --rm --gpus all nvidia/cuda:12.0-base nvidia-smi`

### "disk quota exceeded" on Docker pulls
Docker uses overlay2 storage by default. If `dataRoot` is on a small partition:
1. Move data: `my.virtualisation.docker.dataRoot = "/mnt/docker";`
2. Or migrate existing data:
   ```bash
   systemctl stop docker
   mv /var/lib/docker /mnt/docker/
   ln -s /mnt/docker /var/lib/docker
   systemctl start docker
   ```

### Ollama container won't start with GPU
- Check `nvidia-container-toolkit` is installed (enabled via `enableNvidiaContainerToolkit`)
- Check GPU type matches: `ollama.gpu.type = "nvidia"`
- Verify: `docker run --rm --gpus all nvidia/cuda:12.0-base nvidia-smi`

### Port conflict (Ollama default 11434)
Change the port:
```nix
my.services.ollama.port = 11435;
```
Then update opencode's base URL:
```nix
my.programs.opencode.ollamaBaseURL = "http://127.0.0.1:11435/v1";
```
