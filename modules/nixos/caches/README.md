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
| `push.autoScope` | Derive the exclusion list from cross-host closures nightly |
| `push.autoScopeFlake` | Flake to evaluate (default: this generation's source) |
| `push.autoScopeOnCalendar` | Regeneration schedule (default `03:30`) |

## Auto-scoping (`push.autoScope`)

Instead of hand-maintaining "this is host-specific" patterns, a nightly job
(`cachix-auto-scope-<name>`) evaluates **every** `nixosConfigurations` host's
toplevel derivation, collects the set of derivation *names* per host, and writes
the names that appear in **exactly one** host to
`/var/lib/cachix-push/<cacheName>-auto-exclude`. Both the timer push and the
post-build hook read that file in addition to `excludePatterns`.

Two deliberate choices:

- **Names, not store hashes.** Hashes change with every revision, so a
  hash-based allowlist silently stops matching after a rebuild (the eval'd
  desktop toplevel drv and the installed one already differ in this repo). A
  name like `houdini-22.0.368` is revision-stable.
- **Name-level uniqueness, not path-level.** If two hosts both contain *some*
  derivation called `source`, `source` counts as shared and is never excluded —
  which kills the collision problem that plagues ad-hoc "exclude by name" lists.
  Patterns are anchored (`-<name>$`) so a shorter name cannot match a longer one.

It refuses to publish a partial list: if any host fails to evaluate, the
previous file is left untouched (a missing host would make its names look
exclusive and over-exclude shared paths).

Measured on 6 hosts / 27,933 unique drvs: 12,069 drvs are single-host, and the
generated list (3,428 names) matches 620 paths of the desktop closure. Note this
mostly removes paths that would never upload anyway (`cachix push` already skips
anything upstream-substitutable) — its real targets are locally built
single-host derivations such as the Houdini toolchain.

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
