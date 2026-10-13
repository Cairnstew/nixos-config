{ config, lib, ... }:

let
  cfg = config.my.system.nix-ld;
in
{
  config = lib.mkIf cfg.enable {
    # NixOS' own nix-ld module does the work: it links /lib64/ld-linux-x86-64.so.2
    # to nix-ld instead of the stub-ld shim, installs the library set, and
    # exports NIX_LD / NIX_LD_LIBRARY_PATH as session variables.
    #
    # Both are needed: NixOS' stub-ld (`environment.stub-ld.enable = true` by
    # default) is what prints "Could not start dynamically linked executable …
    # stub-ld" for every binary Zed downloads (its own Node, ruff, …). nix-ld
    # assigns `environment.ldso` without mkDefault, so it overrides the stub.
    programs.nix-ld = {
      enable = true;

      # Host-added libraries are *added* to nixpkgs' default set, never a
      # replacement. `programs.nix-ld.libraries` is a list option, so the two
      # definitions merge by concatenation; `mkAfter` only pins the order
      # (defaults first). tests.nix asserts the defaults survive the merge, so
      # anything that would drop them (an mkForce override, or a future nixpkgs
      # change) fails evaluation instead of silently breaking the binaries that
      # already work.
      libraries = lib.mkAfter cfg.libraries;
    };
  };
}
