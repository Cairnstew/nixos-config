{ lib, ... }:
let
  inherit (import ./cache-type.nix { inherit lib; }) cacheOpts;
in
{
  options.my.caches = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule cacheOpts);
    default = { };
    description = ''
      Binary caches (substituters) for this NixOS host.

      Defaults to the flake-level cache configuration.
      Override per-cache to disable or customize on this host.
    '';
  };
}
