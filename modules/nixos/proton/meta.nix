{
  name = "proton";
  description = "Enhanced Proton support for Steam — GE-Proton, ProtonUp-Qt, extra compat packages";
  category = "gaming";
  tags = [ "gaming" "steam" "proton" "proton-ge" "wine" ];
  provides = [ "my.programs.proton" ];
  expects = [ "programs.steam" ];
  complexity = "simple";
  tested = true;
}
