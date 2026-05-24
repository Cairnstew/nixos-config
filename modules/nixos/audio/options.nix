{ lib, ... }:
{
  options.my.system.audio = {
    enable = lib.mkEnableOption "PipeWire audio stack with Bluetooth and WirePlumber";
  };
}
