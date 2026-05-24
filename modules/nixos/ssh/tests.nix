{ config, lib, ... }:
let
  cfg = config.my.services.ssh;
in
{
  assertions = [
    {
      assertion = !cfg.enable || config.services.openssh.enable;
      message = "SSH module requires services.openssh.enable to be set.";
    }
  ];
}
