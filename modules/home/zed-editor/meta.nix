{
  name = "zed-editor";
  description = "Zed editor with customizable settings, themes, keymaps, and extensions";
  category = "programs";
  tags = [ "zed" "editor" "ide" "code" "lsp" "gui" ];
  provides = [ "my.programs.zed-editor" ];
  expects = [ "flake.config.me.colorScheme" "flake.config.preferences" ];
  complexity = "simple";
  tested = true;
  homepage = "https://zed.dev";
  maintainer = "seanc";
}
