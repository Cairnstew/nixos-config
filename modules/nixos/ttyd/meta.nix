{
  name = "ttyd";
  description = "ttyd web terminal for browser-based emergency SSH access";
  category = "networking";
  tags = [ "ssh" "ttyd" "web" "terminal" "remote" "resilience" "emergency" ];
  provides = [ "my.services.ttyd" ];
  expects = [ "my.services.proxy" ];
  complexity = "simple";
  tested = true;
  maintainer = "seanc";
}
