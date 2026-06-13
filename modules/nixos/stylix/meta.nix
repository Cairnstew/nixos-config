{
  name = "stylix";
  description = "Stylix theming framework integration — wires me.colorScheme to stylix.base16Scheme";
  category = "theming";
  tags = [ "theming" "stylix" "base16" "catppuccin" "colors" ];
  provides = [ "my.theming.stylix" ];
  expects = [ "me.colorScheme" "preferences" ];
  complexity = "low";
  tested = true;
  maintainer = "seanc";
}
