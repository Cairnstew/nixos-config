{
  name = "theming";
  description = "Central colour/theme infrastructure — resolves one scheme into a role-based palette every module reads as my.theming.colors";
  category = "theming";
  tags = [
    "theming"
    "colors"
    "palette"
    "base16"
    "stylix"
    "wcag"
  ];
  provides = [
    "my.theming.colors"
    "my.theming.lib"
    "my.theming.scheme"
    "my.theming.polarity"
    "my.theming.schemes"
  ];
  expects = [
    "flake.config.theming"
  ];
  complexity = "medium";
  tested = true;
  maintainer = "seanc";
}
