{
  name = "profiles";
  description = "System and home profiles for easy host configuration — bundles of related services and programs";
  category = "core";
  tags = [ "profiles" "workstation" "server" "desktop" "gpu" "gaming" "development" "media" ];
  provides = [
    "my.profiles"
    "my.homeProfiles"
  ];
  # Refresh F10b: expects mirrors what profiles/system/config.nix and
  # profiles/home/default.nix actually consume (verified against their blocks).
  expects = [
    "my.desktop.hyprland" # hyprland + choice=hyprland profile blocks set my.desktop.hyprland.*
    "my.desktop.gnome" # gnome + choice=gnome profile blocks set my.desktop.gnome.enable
    "my.hardware.gpu.nvidia" # nvidia / nvidia-headless profiles set my.hardware.gpu.nvidia.*
    "my.hardware.gpu.mesa" # mesa profile sets my.hardware.gpu.mesa.enable
    "my.system.battery" # battery profile sets my.system.battery.enable
    "my.system.location" # location profile sets my.system.location.enable
    "my.testing" # testing profile sets my.testing.enable
    "my.theming.stylix" # theming.stylix profile sets my.theming.stylix.enable
    "home-manager.users.<name>.my.desktop.gnome" # power.desktop/laptop profiles set HM gnome lock/screen-blank options
  ];
  complexity = "medium";
  tested = true;
  maintainer = "seanc";
}
