# =============================================================================
# overlays/default.nix — Custom Package Overrides and Additions
# =============================================================================
# Purpose: Extends nixpkgs with custom packages and overlays from flake inputs.
#
# Packages added:
#   - nuenv — Nushell-based environment management (from flake input)
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

  # Interactive Nix flake template selector
  nix-template-selector = self.callPackage "${packages}/nix-template-selector.nix" { };

  # GitHub Actions workflow run cleanup tool
  github-actions-cleanup = self.callPackage "${packages}/github-actions-cleanup" { };

  # wimboot 2.8.0 fails with GCC -Werror=unterminated-string-initialization
  # Suppress the specific warning until upstream fixes it
  wimboot = super.wimboot.overrideAttrs (old: {
    env = (old.env or { }) // {
      NIX_CFLAGS_COMPILE = (old.env.NIX_CFLAGS_COMPILE or "") + " -Wno-error=unterminated-string-initialization";
    };
  });
}
