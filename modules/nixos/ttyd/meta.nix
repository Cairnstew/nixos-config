{
  name = "ttyd";
  description = "ttyd web terminal for browser-based emergency SSH access";
  category = "networking";
  tags = [ "ssh" "ttyd" "web" "terminal" "remote" "resilience" "emergency" ];
  provides = [
    "my.services.ttyd"
    "my.services.ttyd.theme"
  ];
  expects = [ "my.services.proxy" ];
  complexity = "simple";
  # xterm.js palette via services.ttyd.clientOptions.theme.
  theme = {
    kind = "web";
    mechanism = "native";
    file = "theme.nix";
  };
  tested = true;
  maintainer = "seanc";
}
