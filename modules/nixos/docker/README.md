# Docker

Docker OCI container runtime and daemon configuration with optional NVIDIA Container Toolkit support for GPU-accelerated containers.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `my.virtualisation.docker.enable` | `false` | Enable Docker container runtime |
| `my.virtualisation.docker.enableOnBoot` | `true` | Start Docker automatically on boot |
| `my.virtualisation.docker.enableNvidiaContainerToolkit` | `false` | Enable NVIDIA Container Toolkit support in Docker |
| `my.virtualisation.docker.package` | `pkgs.docker` | Docker package to use |
| `my.virtualisation.docker.extraOptions` | `""` | Extra daemon command-line options |
| `my.virtualisation.docker.extraPackages` | `[]` | Extra packages in Docker's PATH |
| `my.virtualisation.docker.listenOptions` | `["/run/docker.sock"]` | Listen addresses |
| `my.virtualisation.docker.liveRestore` | `true` | Keep containers alive during daemon restart |
| `my.virtualisation.docker.logDriver` | `"journald"` | Default container log driver |
| `my.virtualisation.docker.storageDriver` | `null` | Storage driver (null = auto) |
| `my.virtualisation.docker.dataRoot` | `null` | Custom data directory path |
| `my.virtualisation.docker.users` | `[]` | Users to add to docker group |
| `my.virtualisation.docker.autoPrune.enable` | `false` | Enable automatic cleanup |
| `my.virtualisation.docker.autoPrune.dates` | `"weekly"` | When to run cleanup |
| `my.virtualisation.docker.rootless.enable` | `false` | Enable rootless mode |

## Usage Example

### Basic Usage

```nix
my.virtualisation.docker = {
  enable = true;
  users = [ "alice" "bob" ];
};
```

### With GPU Support

For systems with NVIDIA GPUs, enable the NVIDIA profile which will configure both drivers and container toolkit:

```nix
# For desktop/laptop with display output
my.profiles.gpu.nvidia.enable = true;

# For headless servers (CUDA workloads)
my.profiles.gpu.nvidia-headless.enable = true;
```

Docker will automatically be configured for CDI (Container Device Interface) GPU access when NVIDIA Container Toolkit is enabled at the system level.

### Rootless Mode

```nix
my.virtualisation.docker = {
  enable = true;
  rootless = {
    enable = true;
    setSocketVariable = true;
  };
};
```

## NVIDIA Container Toolkit

This module uses CDI (Container Device Interface) for modern GPU access in containers:

```bash
# Run a container with GPU access (CDI method)
docker run --device nvidia.com/gpu=all --rm nvidia/cuda:12.0-base nvidia-smi

# Or use the legacy --gpus flag
docker run --gpus all --rm nvidia/cuda:12.0-base nvidia-smi
```

The NVIDIA Container Toolkit is automatically configured when:
1. You enable an NVIDIA GPU profile (`my.profiles.gpu.nvidia.enable` or `my.profiles.gpu.nvidia-headless.enable`)
2. The `hardware.nvidia-container-toolkit.enable` option is set to `true`

## Testing

Run the smoke test manually:

```bash
sudo systemctl start docker-smoke-test
sudo systemctl status docker-smoke-test
```

## Notes

- The `docker` group grants root-equivalent privileges. Only add trusted users.
- NVIDIA support requires properly configured NVIDIA drivers - use the GPU profiles.
- Rootless mode is incompatible with the `users` option (no docker group needed).
- CDI (Container Device Interface) is the modern approach for GPU access.
