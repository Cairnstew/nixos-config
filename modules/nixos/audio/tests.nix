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
  ];
}
