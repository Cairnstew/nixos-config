{
  name = "zed-editor";
  description = "Zed editor with customizable settings, themes, keymaps, extensions, and tailnet-aware remote SSH connections";
  category = "programs";
  tags = [ "zed" "editor" "ide" "code" "lsp" "gui" "remote" "ssh" "tailscale" ];
  provides = [
    "my.programs.zed-editor"
    "my.programs.zed-editor.theme"
  ];
  expects = [ "my.theming.colors" "flake.config.preferences" "flake.config.tailnet" ];
  complexity = "moderate";
  tested = true;
  theme = {
    kind = "gui";
    mechanism = "generated";
    file = "theme.nix";
  };
  homepage = "https://zed.dev";
  maintainer = "seanc";
}
