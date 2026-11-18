# modules/nixos/python-tofu/tests.nix
# L0 assertions only: the systemd unit is declared upstream, so there is no
# local L1/L2 probe to add here. Upstream ships its own `module-vm` check.
{ config, lib, ... }:

let
  cfg = config.my.services.python-tofu;
  upstream = config.services.python-tofu;
in
{
  assertions = [
    {
      assertion = !cfg.enable || !(cfg.stack != null && cfg.stackFile != null);
      message = "my.services.python-tofu: set either `stack` or `stackFile`, not both — upstream merges them into one evaluated stack.";
    }
    {
      assertion =
        !cfg.enable
        || !(cfg.stack != null || cfg.stackFile != null)
        || upstream.settings.config == null;
      message = "my.services.python-tofu: `stack`/`stackFile` are mutually exclusive with `services.python-tofu.settings.config`.";
    }
    {
      assertion =
        !cfg.enable
        || !cfg.applyOnRebuild
        || cfg.stack != null
        || cfg.stackFile != null
        || upstream.settings.config != null;
      message = "my.services.python-tofu.applyOnRebuild needs a stack source: set `my.services.python-tofu.stack`, `.stackFile`, or upstream `services.python-tofu.settings.config`.";
    }
  ];
}
