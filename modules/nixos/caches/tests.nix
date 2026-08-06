{ config, lib, ... }:
let
  # Attrset of caches, filtered to those enabled as substituters.
  enabledCaches = lib.filterAttrs (name: cache: cache.enable) config.my.caches;
  # Subset of enabled caches that also have periodic push enabled.
  pushCaches = lib.filterAttrs (name: cache: cache.push.enable) enabledCaches;
in
{
  # ── L0: Nix assertions ──────────────────────────────────────────────────────
  assertions = [
    # Every enabled substituter must name a concrete URL and trusted key.
    {
      assertion = lib.all (cache: cache.substituter != "") (lib.attrValues enabledCaches);
      message = "my.caches.<name>.substituter must be set for every enabled cache.";
    }
    {
      assertion = lib.all (cache: cache.publicKey != "") (lib.attrValues enabledCaches);
      message = "my.caches.<name>.publicKey must be set for every enabled cache.";
    }
    # Periodic push requires an auth token file (usually wired from agenix).
    {
      assertion = lib.all (cache: cache.push.tokenFile != null) (lib.attrValues pushCaches);
      message = "my.caches.<name>.push.tokenFile must be set when push is enabled.";
    }
  ];
}
