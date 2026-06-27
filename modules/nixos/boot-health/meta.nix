{
  name = "boot-health";
  description = "Boot success/failure tracking with optional automatic rollback on emergency detection";
  category = "reliability";
  tags = [ "reliability" "boot" "rollback" "health" "monitoring" ];
  provides = [ "my.services.bootHealth" ];
  expects = [ "my.secrets" "my.homeManager" ];
  complexity = "medium";
  tested = false;
  maintainer = "seanc";
}
