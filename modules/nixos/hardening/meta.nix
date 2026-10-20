{
  name = "hardening";
  description = "Remote-availability hardening: zram, systemd-oomd + earlyoom, cgroup memory caps, OOM-protected SSH-critical services, hardware watchdog/SysRq";
  category = "reliability";
  tags = [
    "reliability"
    "hardening"
    "oom"
    "memory"
    "cpu"
    "zram"
    "swap"
    "ssh"
    "earlyoom"
    "watchdog"
    "sysrq"
    "cgroup"
  ];
  provides = [ "my.system.hardening" ];
  expects = [ "my.services.ssh" ];
  complexity = "medium";
  tested = true;
  maintainer = "seanc";
}
