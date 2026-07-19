{ config, lib, pkgs, flake, ... }:
let
  inherit (import ./cache-type.nix { inherit lib; })
    mkSubstituters mkPublicKeys mkPushServices mkPushAssertions;
in
{
  config = {
    my.caches = lib.mapAttrs (name: cache: lib.mkDefault cache) (flake.config.my.caches or { });

    nix.settings = {
      substituters = mkSubstituters config.my.caches;
      trusted-public-keys = mkPublicKeys config.my.caches;
    };

    systemd.services = (mkPushServices config.my.caches pkgs).services;
    systemd.timers = (mkPushServices config.my.caches pkgs).timers;

    assertions = mkPushAssertions config.my.caches;
  };
}
