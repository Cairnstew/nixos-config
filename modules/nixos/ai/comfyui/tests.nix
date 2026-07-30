{ config, lib, ... }:
let
  cfg = config.my.services.comfyui;
in
{
  assertions = [
    {
      assertion = !cfg.enable || cfg.port > 0;
      message = "my.services.comfyui.port must be a valid port number.";
    }
    {
      assertion = !cfg.enable || cfg.dataDir != "";
      message = "my.services.comfyui.dataDir must not be empty.";
    }
    {
      assertion = !cfg.enable || !cfg.enableManager || cfg.customNodes ? ComfyUI-Manager;
      message = ''
        my.services.comfyui.enableManager requires ComfyUI-Manager in customNodes.
        Add:
          my.services.comfyui.customNodes.ComfyUI-Manager = {
            url = "https://github.com/ltdrdata/ComfyUI-Manager";
          };
      '';
    }
    {
      assertion = !cfg.enable || lib.all (n: n.url != "") (lib.attrValues (lib.filterAttrs (_: n: n.enable) cfg.customNodes));
      message = "my.services.comfyui.customNodes: each enabled node must have a non-empty url.";
    }
  ];
}
