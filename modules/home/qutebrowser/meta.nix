{
  name = "qutebrowser";
  description = "qutebrowser with 1Password CLI userscript and Google sign-in User-Agent fix";
  category = "programs";
  tags = [ "browser" "qutebrowser" "1password" "oauth" "google" ];
  provides = [
    "my.programs.qutebrowser"
    "my.programs.qutebrowser.theme"
  ];
  complexity = "low";
  theme = {
    kind = "gui";
    mechanism = "native";
    file = "theme.nix";
  };
  tested = false;
  maintainer = "seanc";
}
