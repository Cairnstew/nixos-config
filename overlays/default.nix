# =============================================================================
# overlays/default.nix — Custom Package Overrides and Additions
# =============================================================================
# Purpose: Extends nixpkgs with custom packages and overlays from flake inputs.
#
# Packages added:
#   - nuenv — Nushell-based environment management (from flake input)
#   - fuckport — Kill processes using a specific port
#   - twitter-convert — Twitter/X video downloader/converter
#   - sshuttle-via — SSHuttle wrapper for easy proxying
#   - copy-md-as-html — Markdown to HTML clipboard converter
#   - ci — Local CI runner using omnix and zellij
#   - touchpr — GitHub PR toucher/commenter
#   - git-merge-and-delete — Merge branch and clean up
#   - nix-template-selector — Interactive flake template selector
#
# Why overrides are needed:
#   - These packages are either not in nixpkgs or need custom configurations
#   - Some are personal scripts/tools that don't belong upstream
#
# Consumed by: All NixOS/darwin configurations via `lib.attrValues self.overlays`
# =============================================================================

{ flake, ... }:

let
  inherit (flake) inputs;
  inherit (inputs) self;
  packages = self + /packages;
in
self: super: {
  # Nushell environment overlay from nuenv flake input
  nuenv = (inputs.nuenv.overlays.nuenv self super).nuenv;

  # Kill processes by port number (custom script)
  fuckport = self.callPackage "${packages}/fuckport.nix" { };

  # Twitter/X media downloader (custom wrapper)
  twitter-convert = self.callPackage "${packages}/twitter-convert" { };

  # SSHuttle wrapper for tunneling traffic via SSH
  sshuttle-via = self.callPackage "${packages}/sshuttle-via.nix" { };

  # Convert Markdown files to HTML and copy to clipboard
  copy-md-as-html = self.callPackage "${packages}/copy-md-as-html.nix" { };

  # Local CI runner with omnix and zellij
  ci = self.callPackage "${packages}/ci" { };

  # GitHub PR automation tool
  touchpr = self.callPackage "${packages}/touchpr" { };

  # Omnix is available from inputs.omnix directly (commented: use overlay if needed)
  #omnix = inputs.omnix.packages.${self.system}.default;

  # Merge git branch to main, push, and delete branch
  git-merge-and-delete = self.callPackage "${packages}/git-merge-and-delete.nix" { };

  # Interactive Nix flake template selector
  nix-template-selector = self.callPackage "${packages}/nix-template-selector.nix" { };

  # GitHub Actions workflow run cleanup tool
  github-actions-cleanup = self.callPackage "${packages}/github-actions-cleanup" { };

  # wimboot 2.8.0 fails with GCC -Werror=unterminated-string-initialization
  # Suppress the specific warning until upstream fixes it
  wimboot = super.wimboot.overrideAttrs (old: {
    env = (old.env or {}) // {
      NIX_CFLAGS_COMPILE = (old.env.NIX_CFLAGS_COMPILE or "") + " -Wno-error=unterminated-string-initialization";
    };
  });
}
