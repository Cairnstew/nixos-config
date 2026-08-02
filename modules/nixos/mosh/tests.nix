{ config, ... }:
let
  cfg = config.my.services.mosh;
in
{
  assertions = [
    {
      assertion = !cfg.enable || config.services.openssh.enable or false;
      message = ''
        my.services.mosh requires SSH to be enabled because mosh bootstraps
        each session over SSH. Enable my.services.ssh first.
      '';
    }
  ];
}
