# modules/nixos/caches/default.nix
# NixOS module for binary cache management.
#
# Declares my.caches options with defaults from the flake-level config,
# applies enabled caches to nix.settings, and generates systemd push services.
{ config, lib, pkgs, flake, ... }:

let
  inherit (import ./cache-type.nix { inherit lib; })
    cacheOpts mkSubstituters mkPublicKeys mkPushServices mkPushAssertions;
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

  config = {
    # Default each cache from the flake-level values (mkDefault allows host overrides)
    my.caches = lib.mapAttrs (name: cache: lib.mkDefault cache) (flake.config.my.caches or { });

    # Apply to Nix daemon settings
    nix.settings = {
      substituters = mkSubstituters config.my.caches;
      trusted-public-keys = mkPublicKeys config.my.caches;
    };

    # Push services and timers
    systemd.services = (mkPushServices config.my.caches pkgs).services;
    systemd.timers = (mkPushServices config.my.caches pkgs).timers;

    # Assertions
    assertions = mkPushAssertions config.my.caches;
  };
}
