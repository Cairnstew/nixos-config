{
  name = "zed-editor";
  description = "Zed editor with customizable settings, themes, keymaps, extensions, and tailnet-aware remote SSH connections";
  category = "programs";
  tags = [ "zed" "editor" "ide" "code" "lsp" "gui" "remote" "ssh" "tailscale" ];
  provides = [ "my.programs.zed-editor" ];
  expects = [ "flake.config.me.colorScheme" "flake.config.preferences" "flake.config.tailnet" ];
  complexity = "moderate";
  tested = true;
  homepage = "https://zed.dev";
  maintainer = "seanc";
}
