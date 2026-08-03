# Audio

PipeWire audio stack with ALSA, PulseAudio compatibility, Bluetooth support, a
declared default microphone, and an optional Pulsemeeter + EasyEffects virtual
mixer (VoiceMeeter-style).

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `my.system.audio.enable` | `false` | Enable PipeWire audio |
| `my.system.audio.mic.enable` | `false` | Declare a default microphone |
| `my.system.audio.mic.name` | `null` | PipeWire source node name (from `wpctl status`) |
| `my.system.audio.mic.description` | `null` | Human-readable mic label |
| `my.system.audio.virtualMixer.enable` | `false` | Pulsemeeter + EasyEffects virtual mixer |
| `my.system.audio.virtualMixer.effects` | `true` | Include EasyEffects (EQ/compression/noise reduction) |
| `my.system.audio.virtualMixer.patchbay` | `none` | GUI patchbay: `none` or `qpwgraph` |
| `my.system.audio.virtualMixer.autostart` | `true` | Start mixer as systemd user services |
| `my.system.audio.virtualMixer.virtualSinks` | `[]` | Declarative PipeWire null-audio-sinks |
| `my.system.audio.virtualMixer.virtualSinks.<name>.name` | — | PipeWire node name (e.g. `sink.music`) |
| `my.system.audio.virtualMixer.virtualSinks.<name>.description` | — | Human-readable label in audio apps |
| `my.system.audio.virtualMixer.virtualSinks.<name>.channels` | `2` | Number of channels (2 = stereo, 6 = 5.1) |

## Usage

```nix
my.system.audio = {
  enable = true;
  virtualMixer = {
    enable = true;
    patchbay = "qpwgraph";
  };
  mic = {
    enable = true;
    name = "alsa_input.usb-C-Media_Electronics_Inc._USB_PnP_Sound_Device-00.analog-stereo";
    description = "USB headset";
  };
};
```

## Notes

- Pulsemeeter creates its own virtual buses at runtime; `virtualSinks` adds
  extra declarative null sinks that survive without the mixer running.
- The declared mic is baked into a WirePlumber config as the default source at
  build time (no runtime `wpctl set-default` needed). Find the node name with
  `wpctl status` under "Sources".
- `security.rtkit.enable` is set for realtime audio priority.
- Requires `services.pipewire.pulse.enable` (set by this module) — a real
  PulseAudio daemon would break Pulsemeeter's pulsectl control.
- No VoiceMeeter macro-buttons / VBAN equivalent; use EasyEffects presets or
  `pw-link` scripts for that.

## Related Modules

- **Imported by** [`modules/nixos/common.nix`](../common.nix) — enabled on all hosts via `my.*` options.
