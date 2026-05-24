# Graphics

GPU and graphics driver configuration for NVIDIA, AMD/Intel (Mesa), and Vulkan.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `my.hardware.graphics.enable` | `false` | Base graphics stack (OpenGL + 32-bit) |
| `my.hardware.xserver.enable` | `false` | Enable X server |
| `my.hardware.xserver.videoDriver` | `["auto"]` | Xorg video drivers |
| `my.hardware.gpu.nvidia.enable` | `false` | NVIDIA proprietary drivers |
| `my.hardware.gpu.nvidia.headless` | `false` | NVIDIA headless (CUDA only) |
| `my.hardware.gpu.nvidia.cuda` | `false` | Allow unfree CUDA packages |
| `my.hardware.gpu.amd.enable` | `false` | AMDGPU driver explicitly |
| `my.hardware.gpu.mesa.enable` | `false` | Mesa drivers (Intel/AMD) |
| `my.hardware.vulkan.enable` | `false` | Vulkan loader + validation layers |

## Usage

Use via profiles rather than directly:

```nix
my.profiles.gpu.mesa.enable = true;
my.profiles.gpu.nvidia.enable = true;
my.profiles.gpu.nvidia-headless.enable = true;
```
