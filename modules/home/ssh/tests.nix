{ config, lib, ... }:

let
  cfg = config.my.services.ssh;
in
{
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.keyType != "";
        message = "my.services.ssh.keyType must not be empty.";
      }
      {
        assertion = cfg.keyPath != "";
        message = "my.services.ssh.keyPath must not be empty.";
      }
      {
        assertion = cfg.email != "";
        message = "my.services.ssh.email must not be empty.";
      }
    ];
  };
}
