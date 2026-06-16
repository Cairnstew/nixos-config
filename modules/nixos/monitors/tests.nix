{ config, lib, ... }:
let
  cfg = config.my.monitors;
in
{
  assertions = [
    {
      assertion = !(cfg != [ ] && (lib.length (lib.filter (m: m.primary) cfg)) > 1);
      message = "Only one monitor can be set as primary.";
    }
  ];
}
