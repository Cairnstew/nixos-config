{
  name = "ghostty";
  description = "Ghostty terminal emulator with custom themes, keybindings, and settings";
  category = "programs";
  tags = [ "terminal" "emulator" "ghostty" "gui" "gpu-accelerated" ];
  provides = [ "my.programs.ghostty" ];
  expects = [ "flake.config.preferences" "flake.config.defaults" ];
  complexity = "medium";
  tested = true;
  homepage = "https://ghostty.org";
  maintainer = "seanc";
}
