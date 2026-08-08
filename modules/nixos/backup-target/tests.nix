{ config, ... }:
let
  cfg = config.my.services.backup-target;
in
{
  assertions = [
    {
      assertion = !cfg.enable || cfg.targetDir != "/";
      message = "my.services.backup-target: targetDir must not be the root filesystem root (the root NVMe on the server has little free space — Tier 0 §1.3).";
    }
    {
      assertion = !cfg.enable || cfg.targetDir != "/boot";
      message = "my.services.backup-target: targetDir must not be the boot partition.";
    }
    {
      assertion = !cfg.enable || config.services.openssh.enable;
      message = "my.services.backup-target: requires my.services.ssh (openssh) to be enabled — sources push over SFTP on port 22.";
    }
    {
      assertion = !cfg.enable || cfg.user != "";
      message = "my.services.backup-target: user must not be empty when enabled.";
    }
  ];
}
