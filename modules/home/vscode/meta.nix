{
  name = "vscode";
  description = "Visual Studio Code editor configuration with extensions and Continue AI integration";
  category = "development";
  tags = [ "editor" "vscode" "continue" "ai" ];
  provides = [
    "my.programs.vscode"
    "my.programs.vscode.theme"
  ];
  complexity = "medium";
  theme = {
    kind = "gui";
    mechanism = "generated";
    file = "theme.nix";
  };
  tested = true;
}
