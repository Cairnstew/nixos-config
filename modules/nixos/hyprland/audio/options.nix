{ lib, ... }:
{
  options.my.desktop.hyprland.audio = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable PipeWire audio with WirePlumber session manager.";
    };
  };
}
