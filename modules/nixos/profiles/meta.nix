{
  name = "profiles";
  description = "System and home profiles for easy host configuration — bundles of related services and programs";
  category = "core";
  tags = [ "profiles" "workstation" "server" "desktop" "gpu" "gaming" "development" ];
  provides = [
    "my.profiles"
    "my.homeProfiles"
  ];
  expects = [ "my.hardware" "my.desktop.gnome" "my.system.battery" ];
  complexity = "medium";
  tested = true;
  maintainer = "seanc";
}
