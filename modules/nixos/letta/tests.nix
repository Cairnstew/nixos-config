{ config, lib, ... }:
let
  cfg = config.my.services.letta;
in
{
  assertions = [
    {
      assertion = !cfg.enable || cfg.dataDir != "";
      message = "my.services.letta.dataDir must not be empty.";
    }
    {
      assertion = !cfg.enable || cfg.port > 0;
      message = "my.services.letta.port must be a valid port number.";
    }
    {
      assertion = !cfg.enable || cfg.database.type != "postgres" || cfg.database.url != null;
      message = "my.services.letta.database.url must be set when using PostgreSQL.";
    }
  ];
}
