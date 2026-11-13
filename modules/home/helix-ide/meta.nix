{
  name = "helix-ide";
  description = "Helix editor + Zellij terminal multiplexer IDE environment";
  category = "programs";
  tags = [ "helix" "zellij" "editor" "ide" "terminal" ];
  provides = [
    "my.programs.helix-ide"
    "my.programs.helix-ide.theme"
  ];
  expects = [ "my.theming.colors" ];
  complexity = "simple";
  theme = {
    kind = "tui";
    mechanism = "generated";
    file = "theme.nix";
  };
  tested = true;
  maintainer = "seanc";
}
