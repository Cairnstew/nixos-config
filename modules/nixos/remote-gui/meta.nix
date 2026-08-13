{
  name = "remote-gui";
  description = "Virtual X display (Xvfb) shared via x11vnc to view headless GUI apps (e.g. Prism Launcher) from other hosts";
  category = "desktop";
  tags = [ "x11" "vnc" "headless" "remote" "prismlauncher" ];
  provides = [ "my.services.remoteGui" ];
  expects = [ ];
  complexity = "medium";
  tested = true;
  maintainer = "seanc";
}
