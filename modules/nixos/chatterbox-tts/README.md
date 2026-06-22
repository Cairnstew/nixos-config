# Chatterbox TTS Server

OpenAI-compatible TTS server with Web UI, voice cloning, and multi-engine support (Original/Multilingual/Turbo).

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `my.services.chatterbox-tts.enable` | `false` | Enable |
| `my.services.chatterbox-tts.port` | `8004` | API port |
| `my.services.chatterbox-tts.host` | `"127.0.0.1"` | Listen address |
| `my.services.chatterbox-tts.backend` | `"cpu"` | Compute backend (cpu/cuda/rocm) |
| `my.services.chatterbox-tts.model` | `"chatterbox-turbo"` | Model type |
| `my.services.chatterbox-tts.openFirewall` | `false` | Open port in firewall |
| `my.services.chatterbox-tts.extraConfig` | `{}` | Extra config.yaml overrides |

## Usage

```nix
my.services.chatterbox-tts = {
  enable = true;
  backend = "cpu";
};
```

## SillyTavern Integration

Point SillyTavern's TTS extension at:

```
http://127.0.0.1:8004/v1/audio/speech
```

The server exposes an OpenAI-compatible `/v1/audio/speech` endpoint.

## Notes

- Model weights are cached in `stateDir/model_cache` (HuggingFace cache) so they persist across deployments.
- CPU-only by default to avoid VRAM contention with Ollama.
- Switch between Original/Turbo/Multilingual engines at runtime via the Web UI dropdown.
