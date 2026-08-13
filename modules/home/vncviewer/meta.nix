{
  name = "vncviewer";
  description = "VNC viewer client with connection presets for viewing remote GUI apps (pairs with my.services.remoteGui)";
  category = "desktop";
  tags = [ "vnc" "remote" "gui" "viewer" "tigervnc" ];
  provides = [ "my.programs.vncviewer" ];
  expects = [ ];
  complexity = "simple";
  tested = true;
  maintainer = "seanc";
  homepage = "https://tigervnc.org";
}
