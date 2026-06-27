{
  name = "boot-alerting";
  description = "Best-effort email alert during emergency mode and confirmed email on next clean boot with failure details";
  category = "reliability";
  tags = [ "reliability" "boot" "emergency" "alerting" "monitoring" ];
  provides = [ "my.services.bootAlerting" ];
  expects = [ "my.secrets" "my.homeManager" "my.services.bootHealth" ];
  complexity = "medium";
  tested = false;
  maintainer = "seanc";
}
