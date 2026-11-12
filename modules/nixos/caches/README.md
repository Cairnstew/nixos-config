# caches — binary substituters and push

Declares `my.caches.<name>` (a substituter + optional push) and wiring it into
`nix.settings`. Flake-level defaults live in `modules/flake-parts/caches.nix`;
this module inherits them **per leaf** (see `config.nix`) so a host can override
one sub-option — e.g. `my.caches.personal.push.enable` — without wiping the
rest of that cache's defaults.

## Options

| Option | Meaning |
|---|---|
| `my.caches.<name>.enable` | Use this cache as a substituter |
| `substituter` / `publicKey` / `priority` | URL, trusted key, ordering (lower first) |
| `cacheName` | Cachix cache name for pushes (derived from a `*.cachix.org` URL) |
| `push.enable` | Create `cachix-push-<name>.service` + `.timer` |
| `push.tokenFile` | Path to the Cachix auth token (agenix) |
| `push.onCalendar` | Timer schedule (default `weekly`; desktop uses `04:00` daily) |
| `push.paths` | Paths to push; empty = `/run/current-system` |
| `push.excludePatterns` | `grep -E -v` patterns dropped before upload |
| `push.maxPathSizeMiB` | Drop single paths whose own NAR is larger than this |
| `push.postBuildHook` | Also push paths the local daemon just built |

## How a push is filtered

1. expand `push.paths` with `nix-store -qR`,
2. drop `excludePatterns` matches (defaults: `nvidia`, CUDA toolchain, kernel
   modules, firmware, Houdini),
3. drop paths over `maxPathSizeMiB` (default 512 MiB — one Houdini/vendor
   toolchain can otherwise eat a free tier),
4. `cachix push`, which itself skips paths already stored on the cache *and*
   paths available from the host's other substituters.

Step 4 is why the cache stays small: on this repo's hosts essentially the whole
system closure is already on `cache.nixos.org`, so a closure push uploads
nothing. **The useful mechanism is `push.postBuildHook`** — it publishes each
path the moment a host actually has to build it (after a nixpkgs bump, an
overlay change, etc.), which is exactly what stops every other host from
rebuilding the same derivation.

## Enabling

```nix
my.caches.personal.push = {
  enable = true;                 # needs push.tokenFile set
  tokenFile = config.age.secrets."nixos-config-cache-token".path;
  postBuildHook = true;          # the part that saves rebuilds
};
```

Only `desktop` pushes today (`configurations/nixos/desktop/default.nix`); every
host substitutes from the cache.

## Verify

```bash
nix eval .#nixosConfigurations.desktop.config.nix.settings.substituters --json
grep -E 'substituters|post-build-hook' /etc/nix/nix.conf
systemctl list-timers cachix-push-personal.timer
journalctl -u cachix-push-personal.service -n 20
nix path-info --store https://cairnstew-nixos-config-cache.cachix.org /nix/store/…  # present?
```
