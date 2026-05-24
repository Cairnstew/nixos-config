{ config, lib, ... }:
let
  cfg = config.my.services.ollama;
in
{
  assertions = [
    {
      assertion = !cfg.enable || cfg.dataDir != "";
      message = "my.services.ollama.dataDir must not be empty.";
    }
    {
      assertion = !cfg.enable || cfg.port > 0;
      message = "my.services.ollama.port must be a valid port number.";
    }
  ];
}
