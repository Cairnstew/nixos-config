{ config, lib, ... }:
let
  cfg = config.my.system.audio;
in
{
  assertions = [
    {
      assertion = !cfg.enable || config.services.pipewire.enable;
      message = "Audio module requires services.pipewire.enable to be true.";
    }
    {
      assertion = !cfg.virtualMixer.enable || cfg.enable;
      message = "my.system.audio.virtualMixer.enable requires my.system.audio.enable.";
    }
    {
      assertion = !cfg.mic.enable || cfg.mic.name != null;
      message = "my.system.audio.mic.enable requires my.system.audio.mic.name (find it with `wpctl status`).";
    }
    {
      # WirePlumber treats the value as a linear volume ratio; the schema clamps
      # device.routes.default-sink-volume to [0.0, 1.0].
      assertion = builtins.all (v: v >= 0.0 && v <= 1.0) (lib.attrValues cfg.deviceDefaultVolumes);
      message = "my.system.audio.deviceDefaultVolumes values must be between 0.0 and 1.0.";
    }
  ];
}
