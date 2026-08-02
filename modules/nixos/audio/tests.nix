{ config, ... }:
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
  ];
}
