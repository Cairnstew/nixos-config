{ config, lib, ... }:
let
  inherit (lib) mkIf;
  cfg = config.my.programs.squidProxyClient;
in
{
  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.serverAddress != "";
        message = "my.programs.squidProxyClient: serverAddress must not be empty.";
      }
    ];
  };
}
