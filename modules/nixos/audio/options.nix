{ lib, ... }:
{
  options.my.system.audio = {
    enable = lib.mkEnableOption "PipeWire audio stack with Bluetooth and WirePlumber";

    deviceDefaultVolumes = lib.mkOption {
      type = lib.types.attrsOf lib.types.number;
      default = { };
      example = { "alsa_card.pci-0000_09_00.4" = 0.8; };
      description = ''
        Per-device default sink volume (0.0-1.0 linear), keyed by WirePlumber
        `device.name` (e.g. `alsa_card.pci-0000_09_00.4`). Raise passive analog
        outputs (headphone jacks that rely entirely on the motherboard DAC/amp)
        above the global crate default (0.064 linear, shown as ~40%) without
        affecting already-loud self-amplified outputs like Bluetooth headsets.
        Set via WirePlumber's per-device `device.routes.default-sink-volume`
        property — `apply-routes.lua` reads it as a per-device override over the
        global `device.routes.default-sink-volume`. Note the value uses PipeWire's
        linear volume scale (1.0 = 100%): the displayed `wpctl` percentage is the
        cubic root, so 0.8 shows as ~93% and 1.0 as 100%. Find the card name with
        `wpctl status -n` under Devices. A device restored from WirePlumber's
        runtime state keeps its stored volume until cleared (`wpctl reset`).
      '';
    };

    mic = {
      enable = lib.mkEnableOption "a declared default microphone (baked into WirePlumber config as the default audio source)";
      name = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          PipeWire source node name of the physical microphone, from `wpctl status`.
          Used to generate the WirePlumber default-source policy.
        '';
        example = "alsa_input.usb-C-Media_Electronics_Inc._USB_PnP_Sound_Device-00.analog-stereo";
      };
      description = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Human-readable label for the microphone.";
        example = "USB headset";
      };
    };

    virtualMixer = {
      enable = lib.mkEnableOption "the Pulsemeeter + EasyEffects virtual audio mixer (VoiceMeeter-style)";
      effects = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Include EasyEffects for per-stream EQ, compression, and noise reduction on top of Pulsemeeter.";
      };
      patchbay = lib.mkOption {
        type = lib.types.enum [ "none" "qpwgraph" ];
        default = "none";
        description = "Graphical PipeWire patchbay for manual node/port routing (qpwgraph persists wire sets).";
      };
      autostart = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Start Pulsemeeter (and EasyEffects) as systemd user services on login.";
      };
      virtualSinks = lib.mkOption {
        type = lib.types.listOf (lib.types.submodule {
          options = {
            name = lib.mkOption {
              type = lib.types.str;
              description = "PipeWire node name, e.g. 'sink.music'.";
            };
            description = lib.mkOption {
              type = lib.types.str;
              description = "Human-readable label shown in audio apps.";
            };
            channels = lib.mkOption {
              type = lib.types.int;
              default = 2;
              description = "Number of audio channels (2 = stereo, 6 = 5.1).";
            };
          };
        });
        default = [ ];
        description = ''
          Declarative PipeWire null-audio-sink virtual sinks, in addition to
          Pulsemeeter's runtime-created buses. Requires a pipewire service restart on activation.
        '';
      };
    };
  };
}
