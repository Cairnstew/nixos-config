{
  name = "theming";
  description = "Central colour/theme infrastructure for Home Manager — my.theming.colors, the resolved role-based palette";
  category = "theming";
  tags = [
    "theming"
    "colors"
    "palette"
    "base16"
    "wcag"
  ];
  provides = [
    "my.theming.colors"
    "my.theming.lib"
    "my.theming.scheme"
    "my.theming.schemeUnderscored"
    "my.theming.polarity"
  ];
  expects = [ ];
  complexity = "low";
  tested = true;
  maintainer = "seanc";
}
