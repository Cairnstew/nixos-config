{ lib, ... }:
let
  inherit (lib) mkEnableOption mkOption types;
in
{
  options.my.services.autosshReverse = {
    enable = mkEnableOption "autossh phone-home reverse tunnel to a bastion";

    bastion = mkOption {
      type = types.str;
      default = "";
      description = ''
        Bastion host to tunnel to, in ssh form: user@host or user@host:port.
        The server opens a reverse tunnel to this host so you can reach it via
        plain internet SSH even when every mesh VPN is down. This is a
        completely different transport (plain SSH, not a mesh).
      '';
      example = "seanc@bastion.example.com";
    };

    user = mkOption {
      type = types.str;
      default = "root";
      description = "Local system user the tunnel process runs as.";
    };

    remotePort = mkOption {
      type = types.port;
      default = 22022;
      description = "Remote port opened on the bastion that forwards back to this box's SSH.";
    };

    localPort = mkOption {
      type = types.port;
      default = 22;
      description = "Local SSH port to forward the remote port to.";
    };

    monitoringPort = mkOption {
      type = types.port;
      default = 20001;
      description = "autossh monitoring port (uses port+1 too). 0 disables keep-alive monitoring.";
    };

    identityFile = mkOption {
      type = types.str;
      default = "/root/.ssh/id_ed25519";
      description = "SSH identity used to authenticate to the bastion.";
    };

    extraArguments = mkOption {
      type = types.str;
      default = "";
      description = "Extra arguments appended to the autossh/ssh invocation.";
    };

    serverAliveInterval = mkOption {
      type = types.int;
      default = 15;
      description = "SSH ServerAliveInterval for fast failure detection.";
    };

    serverAliveCountMax = mkOption {
      type = types.int;
      default = 3;
      description = "SSH ServerAliveCountMax before reconnecting.";
    };
  };
}
