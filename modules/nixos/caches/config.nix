{ config, lib, pkgs, flake, ... }:
let
  inherit (import ./cache-type.nix { inherit lib; })
    mkSubstituters mkPublicKeys mkPushServices mkPushAssertions mkPostBuildHook;

  # Post-build hook publishing to every cache that opted in; null if none did.
  hook = mkPostBuildHook config.my.caches pkgs;

  # Flake defaults must be inherited *per leaf*. Wrapping a whole cache
  # submodule value in `mkDefault` (the old behaviour) meant any normal-priority
  # definition of a nested path — e.g. `my.caches.personal.push.enable` from a
  # profile — discarded the entire default, leaving `substituter`/`publicKey`
  # undefined and `enable = false`, so the cache silently vanished from
  # `nix.settings.substituters`.
  mkLeafDefaults = lib.mapAttrsRecursive (_path: value: lib.mkDefault value);

  # Per-cache defaults: flake-level values leaf-by-leaf, plus a push exclusion
  # list that keeps host-specific / oversized outputs out of a small cache.
  cacheDefaults = cache: mkLeafDefaults cache // {
    push = mkLeafDefaults (cache.push or { }) // {
      excludePatterns = lib.mkDefault defaultPushExcludes;
      maxPathSizeMiB = lib.mkDefault defaultMaxPathSizeMiB;
    };
  };

  # Host-specific or oversized outputs a small cache should never hold.
  # Keep these anchored on store-path name boundaries: a bare "cuda" also
  # matched `cudatext`, so vendor toolchains need the vendor-product shape to
  # avoid catching unrelated names.
  defaultPushExcludes = [
    "nvidia"
    "(-cuda-[0-9]|cuda-toolkit|cudatoolkit|libcudnn|tensorrt)"
    "-linux-[0-9].*-modules"
    "-linux-firmware"
    "-firmware-"
    "-houdini"
  ];

  # One multi-gigabyte path (Houdini, big vendor toolchains) can exhaust a free
  # tier by itself, so cap what gets handed to the uploader.
  defaultMaxPathSizeMiB = 512;
in
{
  config = {
    my.caches = lib.mapAttrs (_name: cache: cacheDefaults cache) (flake.config.my.caches or { });

    nix.settings = {
      substituters = mkSubstituters config.my.caches;
      trusted-public-keys = mkPublicKeys config.my.caches;
      # Push freshly built paths the moment the daemon finishes them; this is
      # what stops every other host from rebuilding the same thing.
      post-build-hook = lib.mkIf (hook != null) hook;
    };

    systemd.services = (mkPushServices config.my.caches pkgs).services;
    systemd.timers = (mkPushServices config.my.caches pkgs).timers;

    assertions = mkPushAssertions config.my.caches;
  };
}
