{ config, ... }:
let
  cfg = config.my.services.xmltv;
in
{
  assertions = [
    {
      assertion = !cfg.enable || cfg.outputPath != "";
      message = "my.services.xmltv.outputPath must not be empty.";
    }
    {
      assertion = !cfg.enable || cfg.days > 0;
      message = "my.services.xmltv.days must be positive.";
    }
    {
      assertion = !cfg.enable || cfg.days <= 31;
      message = "my.services.xmltv.days must be 31 or less.";
    }
  ];
}
