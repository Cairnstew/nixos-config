{
  name = "hardening";
  description = "Memory/CPU pressure hardening: zram swap, systemd-oomd, OOM-protected SSH-critical services";
  category = "reliability";
  tags = [ "reliability" "hardening" "oom" "memory" "cpu" "zram" "swap" "ssh" ];
  provides = [ "my.system.hardening" ];
  expects = [ "my.services.ssh" ];
  complexity = "medium";
  tested = true;
  maintainer = "seanc";
}
