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

      excludePatterns = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        example = [ "nvidia" "-linux-[0-9].*-modules" ];
        description = ''
          Extended-regex patterns dropped from the push set before anything is
          uploaded (matched with `grep -E -v` against full store paths).

          Use this to keep things a small/free cache must not hold: derivations
          only one host ever needs (vendor GPU drivers, kernel modules,
          firmware), or very large output that upstream caches already serve.
          Excluded paths are simply never handed to `cachix push`; note that a
          kept path's own dependencies are still uploaded, so exclusion is
          reliable for leaf packages (drivers, kernels) but not for something
          another kept path directly references.
        '';
      };

      maxPathSizeMiB = lib.mkOption {
        type = lib.types.nullOr lib.types.int;
        default = null;
        example = 512;
        description = ''
          Drop any single store path larger than this many MiB before pushing.
          A safety valve for small caches: one multi-gigabyte derivation
          (Houdini, a big vendor toolchain) can eat a free tier on its own.
          `null` disables the cap.
        '';
      };

      postBuildHook = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Also push **newly built** paths the moment the local nix daemon
          finishes building them (`nix.settings.post-build-hook`).

          This is the part that actually saves other hosts rebuilds: a
          timer-based closure push finds almost everything already available
          upstream, while a fresh build after a nixpkgs bump is exactly the
          thing no other cache has yet. The same `excludePatterns` /
          `maxPathSizeMiB` filters apply, so host-specific outputs still never
          leave the machine.
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
        default =
          let
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
  # Filter + push script shared by the timer service and the post-build hook.
  # Candidate store paths come from stdin (one per line) or from argv.
  mkPushScript = name: cache: pkgs':
    let
      p = cache.push;
      cname = if cache.cacheName != "" then cache.cacheName else name;
      patternFile = pkgs'.writeText "cachix-push-excludes-${name}"
        (lib.concatMapStrings (pattern: pattern + "\n") p.excludePatterns);
    in
    pkgs'.writeShellScript "cachix-push-${name}" ''
      set -uo pipefail
      # The post-build hook is spawned by the nix daemon with a minimal
      # environment, so never rely on the caller's PATH.
      export PATH=${lib.makeBinPath [
        pkgs'.coreutils
        pkgs'.findutils
        pkgs'.gnugrep
        pkgs'.jq
        pkgs'.cachix
        pkgs'.nix
      ]}:"$PATH"
      export CACHIX_AUTH_TOKEN="$(cat ${p.tokenFile})"

      work="$(mktemp -d)"
      trap 'rm -rf "$work"' EXIT

      if [ "$#" -gt 0 ]; then printf '%s\n' "$@"; else cat; fi | sort -u > "$work/all"
      ${lib.optionalString (p.excludePatterns != [ ]) ''
        # grep exits 1 when every path is excluded, which is not an error here.
        grep -E -v -f ${patternFile} "$work/all" > "$work/keep" || true
      ''}
      ${lib.optionalString (p.excludePatterns == [ ]) ''
        cp "$work/all" "$work/keep"
      ''}

      ${lib.optionalString (p.maxPathSizeMiB != null) ''
        # Drop single store paths whose own NAR exceeds the cap. (`path-info -S`
        # is closure size, not path size, so read narSize from the JSON form and
        # accept both the array and the path-keyed object shapes.)
        xargs -r -n 500 -a "$work/keep" nix path-info --json --json-format 1 \
          | jq -r --argjson max ${toString (p.maxPathSizeMiB * 1024 * 1024)} '
              (if type == "array"
               then .[] | { name: .path, size: .narSize }
               else to_entries[] | { name: .key, size: .value.narSize }
               end)
              | select(.size > $max) | .name' > "$work/too-big" || true
        if [ -s "$work/too-big" ]; then
          echo "cachix-push-${cname}: dropping $(wc -l < "$work/too-big") path(s) over ${toString p.maxPathSizeMiB} MiB"
          grep -v -F -x -f "$work/too-big" "$work/keep" > "$work/keep2" || true
          mv "$work/keep2" "$work/keep"
        fi
      ''}

      echo "cachix-push-${cname}: $(wc -l < "$work/all") candidate paths, $(wc -l < "$work/keep") kept"

      if [ ! -s "$work/keep" ]; then
        echo "cachix-push-${cname}: nothing left to push"
        exit 0
      fi

      # `cachix push` skips paths already stored on the cache *and* paths this
      # host can substitute from its other substituters, so only self-built
      # paths are actually uploaded.
      # -n 200 keeps argv far below ARG_MAX on large closures; --jobs 2 keeps the
      # uploader's memory (jobs × chunks × chunk-size) polite on an interactive box.
      xargs -r -n 200 cachix push --omit-deriver --jobs 2 ${cname} < "$work/keep"
    '';
in
{
  inherit cacheOpts pushOpts;

  # Collect caches that are enabled as substituters
  enabledCaches = caches: lib.filterAttrs (n: v: v.enable) caches;

  # Build the substituter list sorted by priority (ascending)
  mkSubstituters = caches:
    let
      enabled = lib.filterAttrs (n: v: v.enable) caches;
      sorted = lib.sort (a: b: a.priority < b.priority) (lib.attrValues enabled);
    in
    map (c: c.substituter) sorted;

  mkPublicKeys = caches:
    let
      enabled = lib.filterAttrs (n: v: v.enable) caches;
    in
    map (c: c.publicKey) (lib.attrValues enabled);

  # Build systemd push services for caches with push enabled
  mkPushServices = caches: pkgs':
    let
      pushes = lib.filterAttrs (n: v: v.push.enable) caches;
    in
    {
      services = lib.mapAttrs'
        (name: cache:
          let
            cname = if cache.cacheName != "" then cache.cacheName else name;
            # Push the whole current system by default; hosts opt into a
            # narrower set through `push.paths`.
            targets = if cache.push.paths == [ ] then [ "/run/current-system" ] else cache.push.paths;
          in
          {
            name = "cachix-push-${name}";
            value = {
              description = "Push to Cachix cache: ${cname}";
              after = [ "network-online.target" ];
              wants = [ "network-online.target" ];
              path = [
                pkgs'.coreutils
                pkgs'.findutils
                pkgs'.gnugrep
                pkgs'.jq
                pkgs'.cachix
                pkgs'.nix
              ];
              serviceConfig = {
                Type = "oneshot";
                # A first push of a big closure is slow; never let systemd time it out.
                TimeoutStartSec = "infinity";
                Nice = 19;
                IOSchedulingClass = "idle";
                PrivateTmp = true;
                ExecStart = pkgs'.writeShellScript "cachix-push-service-${name}" ''
                  exec nix-store -qR ${lib.escapeShellArgs targets} | ${mkPushScript name cache pkgs'}
                '';
              };
            };
          })
        pushes;
      timers = lib.mapAttrs'
        (name: cache:
          let
            cname = if cache.cacheName != "" then cache.cacheName else name;
          in
          {
            name = "cachix-push-${name}";
            value = {
              description = "Timer for Cachix push: ${cname}";
              wantedBy = [ "timers.target" ];
              timerConfig = {
                OnCalendar = cache.push.onCalendar;
                Persistent = true;
                # Stagger hosts so several machines never fill the cache at once.
                RandomizedDelaySec = "1h";
              };
            };
          })
        pushes;
    };

  # `nix.settings.post-build-hook`: push freshly built paths immediately.
  # Returns null when no cache opted in.
  mkPostBuildHook = caches: pkgs':
    let
      optedIn = lib.filterAttrs (n: v: v.push.enable && v.push.postBuildHook) caches;
      scripts = lib.mapAttrsToList (name: cache: mkPushScript name cache pkgs') optedIn;
    in
    if scripts == [ ] then
      null
    else
      pkgs'.writeShellScript "cachix-post-build-hook" ''
        # A caching failure must never fail the build that triggered it.
        set -uo pipefail
        [ -n "''${OUT_PATHS:-}" ] || exit 0
        for push in ${lib.concatStringsSep " " scripts}; do
          "$push" $OUT_PATHS || true
        done
        exit 0
      '';

  # Assertions for push config
  mkPushAssertions = caches: lib.flatten (lib.mapAttrsToList
    (name: cache:
      let
        p = cache.push;
      in
      [
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
      ])
    (lib.filterAttrs (n: v: v.push.enable) caches));
}
