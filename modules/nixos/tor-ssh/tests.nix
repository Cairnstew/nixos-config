{ config, ... }:
let
  cfg = config.my.services.torSsh;
in
{
  assertions = [
    {
      assertion = !cfg.enable || config.services.openssh.enable or false;
      message = "my.services.torSsh requires SSH (my.services.ssh) so the onion service has a port to forward to.";
    }
    {
      assertion = !cfg.enable || !cfg.openFirewall;
      message = "my.services.torSsh.openFirewall should be false — an onion service needs no inbound ports.";
    }
  ];
}
