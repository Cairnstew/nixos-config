# modules/nixos/caches/cache-type.nix
# Shared option types and helpers for the caches module.
{ lib, ... }:

let
  pushOpts = {
    options = {
      enable = lib.mkEnableOption "periodic push to this cache via systemd timer";

      tokenFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "Path to file containing Cachix auth token (e.g. from agenix).";
      };

      onCalendar = lib.mkOption {
        type = lib.types.str;
        default = "weekly";
        description = "systemd calendar expression for push frequency. See systemd.time(7).";
      };

      paths = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = ''
          Store paths to push.
          If empty, pushes the current system closure (/run/current-system).
        '';
      };
    };
  };

  cacheOpts = { config, name, ... }: {
    options = {
      enable = lib.mkEnableOption "this binary cache as a substituter";

      substituter = lib.mkOption {
        type = lib.types.str;
        description = "Binary cache substituter URL";
        example = "https://cache.nixos.org/";
      };

      publicKey = lib.mkOption {
        type = lib.types.str;
        description = "Trusted public key for this cache";
        example = "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=";
      };

      priority = lib.mkOption {
        type = lib.types.int;
        default = 0;
        description = "Cache priority (lower = tried first in substituter list).";
      };

      cacheName = lib.mkOption {
        type = lib.types.str;
        default = let
          stripped = lib.removePrefix "https://" (lib.removeSuffix "/" config.substituter);
        in
          lib.optionalString (lib.hasSuffix ".cachix.org" stripped) (lib.removeSuffix ".cachix.org" stripped);
        defaultText = lib.literalExpression ''
          Derived from substituter URL for Cachix caches,
          e.g. "https://my-cache.cachix.org" → "my-cache".
        '';
        description = "Cachix cache name for push operations.";
      };

      push = lib.mkOption {
        type = lib.types.submodule pushOpts;
        default = { };
        description = "Push (write) configuration for this cache.";
      };
    };
  };
in
{
  inherit cacheOpts pushOpts;

  # Collect caches that are enabled as substituters
  enabledCaches = caches: lib.filterAttrs (n: v: v.enable) caches;

  # Build the substituter list sorted by priority (ascending)
  mkSubstituters = caches: let
    enabled = lib.filterAttrs (n: v: v.enable) caches;
    sorted = lib.sort (a: b: a.priority < b.priority) (lib.attrValues enabled);
  in
    map (c: c.substituter) sorted;

  mkPublicKeys = caches: let
    enabled = lib.filterAttrs (n: v: v.enable) caches;
  in
    map (c: c.publicKey) (lib.attrValues enabled);

  # Build systemd push services for caches with push enabled
  mkPushServices = caches: pkgs': let
    pushes = lib.filterAttrs (n: v: v.push.enable) caches;
  in {
    services = lib.mapAttrs' (name: cache: let
      p = cache.push;
      cname = if cache.cacheName != "" then cache.cacheName else name;
    in {
      name = "cachix-push-${name}";
      value = {
        description = "Push to Cachix cache: ${cname}";
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = (pkgs'.writeShellScript "cachix-push-${name}" ''
            export CACHIX_AUTH_TOKEN=$(cat ${p.tokenFile})
            ${if p.paths == [ ]
              then "${pkgs'.cachix}/bin/cachix push ${cname} /run/current-system"
              else lib.concatMapStringsSep "\n" (path: "${pkgs'.cachix}/bin/cachix push ${cname} ${path}") p.paths
            }
          '');
        };
      };
    }) pushes;
    timers = lib.mapAttrs' (name: cache: let
      cname = if cache.cacheName != "" then cache.cacheName else name;
    in {
      name = "cachix-push-${name}";
      value = {
        description = "Timer for Cachix push: ${cname}";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = cache.push.onCalendar;
          Persistent = true;
        };
      };
    }) pushes;
  };

  # Assertions for push config
  mkPushAssertions = caches: lib.flatten (lib.mapAttrsToList (name: cache: let
    p = cache.push;
  in [
    {
      assertion = !p.enable || cache.cacheName != "";
      message = "my.caches.${name}.cacheName must be set when push is enabled. "
        + "Either set it explicitly, or use a Cachix substituter URL. "
        + "Hint: for https://<name>.cachix.org, cacheName = \"<name>\".";
    }
    {
      assertion = !p.enable || p.tokenFile != null;
      message = "my.caches.${name}.push.tokenFile must be set when push is enabled.";
    }
  ]) (lib.filterAttrs (n: v: v.push.enable) caches));
}
