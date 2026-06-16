{ config, lib, ... }:
let
  cfg = config.my.vm;
in
{
  # ── L0: Nix assertions ──────────────────────────────────────────────────────
  assertions = [
    {
      assertion = !cfg.enable || cfg.memory > 0;
      message = "my.vm.memory must be positive when my.vm.enable = true.";
    }
    {
      assertion = !cfg.enable || cfg.cores > 0;
      message = "my.vm.cores must be positive when my.vm.enable = true.";
    }
    {
      assertion = !cfg.enable || cfg.diskSize > 0;
      message = "my.vm.diskSize must be positive when my.vm.enable = true.";
    }
  ];
}
