{ config, lib, ... }:
let
  cfg = config.my.services.risuai;
in
{
  assertions = [
    {
      assertion = !cfg.enable || cfg.dataDir != "";
      message = "my.services.risuai.dataDir must not be empty.";
    }
    {
      assertion = !cfg.enable || cfg.port > 0;
      message = "my.services.risuai.port must be a valid port number.";
    }
    {
      assertion = !cfg.enable || !cfg.ollama.enable || cfg.ollama.baseUrl != "";
      message = "my.services.risuai.ollama.baseUrl must not be empty when ollama integration is enabled.";
    }
  ];
}
