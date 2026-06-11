{
  name = "mouse";
  description = "Mouse acceleration via maccel kernel module with GNOME integration";
  category = "hardware";
  tags = [ "mouse" "maccel" "acceleration" "kernel" ];
  provides = [ "my.hardware.mouse" ];
  expects = [ "my.desktop.gnome" ];
  complexity = "medium";
  tested = true;
  maintainer = "seanc";
  homepage = "https://www.maccel.org";
}
