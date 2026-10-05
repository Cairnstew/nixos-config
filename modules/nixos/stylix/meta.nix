{
  name = "stylix";
  description = "Stylix theming framework integration — feeds my.theming.colors.base16 to stylix";
  category = "theming";
  tags = [ "theming" "stylix" "base16" "catppuccin" "colors" ];
  provides = [ "my.theming.stylix" ];
  expects = [ "my.theming.colors" "preferences" ];
  complexity = "low";
  tested = true;
  maintainer = "seanc";
}
