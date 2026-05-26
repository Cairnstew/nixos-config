{ config, lib, ... }:
let
  cfg = config.my.programs.ventoy;
in
{
  assertions = [
    {
      assertion = !cfg.enable || cfg.package == null || builtins.elem cfg.package [
        "ventoy" "ventoy-full" "ventoy-full-qt" "ventoy-full-gtk"
      ];
      message = "my.programs.ventoy.package must be one of: null, ventoy, ventoy-full, ventoy-full-qt, ventoy-full-gtk";
    }
  ];
}
