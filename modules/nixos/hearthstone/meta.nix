{
  name = "hearthstone";
  description = "Hearthstone native Linux launcher — uses hearthstone-linux-gui flake, no Wine/Battle.net";
  category = "gaming";
  tags = [ "gaming" "hearthstone" "blizzard" "native" "wayland" ];
  provides = [ "my.programs.hearthstone" ];
  expects = [ "my.system.audio" ];
  complexity = "simple";
  tested = true;
}
