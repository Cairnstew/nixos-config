{
  name = "firefox";
  description = "Firefox browser configuration with bookmark and extension support";
  category = "browser";
  tags = [ "browser" "firefox" "web" ];
  provides = [
    "my.programs.firefox"
    "my.programs.firefox.theme"
  ];
  complexity = "simple";
  theme = {
    kind = "gui";
    mechanism = "css-inject";
    file = "theme.nix";
  };
  tested = true;
  homepage = "https://www.mozilla.org/firefox/";
}
