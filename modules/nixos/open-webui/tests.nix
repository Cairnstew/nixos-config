{ config, lib, ... }:
let
  cfg = config.my.services.open-webui;
in
{
  assertions = [
    {
      assertion = !cfg.enable || cfg.dataDir != "";
      message = "my.services.open-webui.dataDir must not be empty.";
    }
    {
      assertion = !cfg.enable || cfg.port > 0;
      message = "my.services.open-webui.port must be a valid port number.";
    }
    {
      assertion = !cfg.enable || !cfg.webSearch.enable || cfg.webSearch.provider != "searxng" || cfg.webSearch.searxngBaseUrl != null;
      message = "my.services.open-webui.webSearch.searxngBaseUrl must be set when using SearXNG provider.";
    }
  ];
}
