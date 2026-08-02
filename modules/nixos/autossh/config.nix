{ config, lib, ... }:
let
  cfg = config.my.services.autosshReverse;
  inherit (lib) mkIf;
in
{
  config = mkIf cfg.enable {
    services.autossh.sessions = [
      {
        name = "phone-home";
        inherit (cfg) user monitoringPort;
        extraArguments = lib.concatStringsSep " " [
          "-N"
          "-o ServerAliveInterval=${toString cfg.serverAliveInterval}"
          "-o ServerAliveCountMax=${toString cfg.serverAliveCountMax}"
          "-o ExitOnForwardFailure=yes"
          "-o ConnectTimeout=10"
          "-o StrictHostKeyChecking=accept-new"
          "-i ${cfg.identityFile}"
          "-R ${toString cfg.remotePort}:localhost:${toString cfg.localPort}"
        ] + (if cfg.extraArguments != "" then " ${cfg.extraArguments}" else "") + " ${cfg.bastion}";
      }
    ];
  };
}
