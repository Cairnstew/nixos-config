# qutebrowser

`my.programs.qutebrowser` — qutebrowser with a 1Password CLI userscript and a
Google sign-in User-Agent fix.

## Two 1Password backends

| Backend | Command | Source | Needs |
|---|---|---|---|
| **Native component** | `:onepass [filter]` | `Cairnstew/qutebrowser` fork (`feature/onepassword`), pinned by `overlays/default.nix` | `op` on `PATH` |
| **Userscript fallback** | `<Ctrl-Shift-p>` / `:1pass [filter]` | `userscripts/qute-1pass.py` in this repo | `op`, `wofi`, `wl-copy` |

The overlay replaces nixpkgs' `qutebrowser` with the fork, so the native command
exists on every host that installs qutebrowser. The userscript is kept as a
fallback for unmodified builds (and for the wofi picker). The two names do not
collide: `:1pass` is the userscript alias, `:onepass` the native command.

Both backends need a CLI account. Recommended (and closest to the Firefox
extension, which delegates unlock to the app): 1Password app →
**Settings → Security** → turn on Linux system authentication, then
**Settings → Developer** → *Integrate with 1Password CLI*. Alternatively run
`op account add` once in a terminal. Without either, both commands report
`the 1Password CLI has no account configured` with these instructions instead
of hanging on `op`'s interactive "add an account manually?" prompt.

Both backends resolve `/run/wrappers/bin/op` when it exists — that setgid
wrapper (group `onepassword-cli`, from `programs._1password`) is what can reach
the app-integration socket, while a plain `op` (the copy installed by
`my.programs.ssh-1password`, or the one in `devShells.secrets`) has no group
access. `QUTE_ONEPASS_OP` overrides the binary (used by the tests).

To bump the fork pin: commit on `feature/onepassword`, push, then update
`rev`/`hash` in `overlays/default.nix`:

```bash
cd ~/Projects/qutebrowser && git push
nix store prefetch-file --unpack --json \
  "https://github.com/Cairnstew/qutebrowser/archive/$(git rev-parse HEAD).tar.gz"
```

## Why there is no "1Password extension"

qutebrowser renders with QtWebEngine (Chromium), but it exposes **no browser
extension API**: Chrome `.crx` extensions and Firefox WebExtensions cannot be
installed. The 1Password desktop extension therefore cannot run in qutebrowser.

Instead there are two `op`-CLI-based integrations: the **native component** in
the fork (preferred, `:onepass`) and this repo's **userscript** (fallback,
`:1pass`), which talks to the 1Password CLI:

| Piece | Path |
|---|---|
| Userscript (source) | `modules/home/qutebrowser/userscripts/qute-1pass.py` |
| Default profile install | `~/.config/qutebrowser/userscripts/qute-1pass.py` |
| Proxy profile install | `~/.config/qutebrowser-proxy/config/userscripts/qute-1pass.py` |
| Key binding | `<Ctrl-Shift-p>` (`onePassword.keybinding`) |
| Command | `:1pass` — `:1pass <title-or-url-fragment>` filters first |

Requirements on `PATH` (all present on the desktop host): `op` (1Password CLI
wired to the desktop app), `wofi` (item picker), `wl-copy` (clipboard),
`jq` is **not** needed (JSON is parsed in Python).

Pressing the binding (or typing `:1pass`) does:

1. lists Login items via `op item list --categories Login --format json`;
2. preselects the items whose URL matches the current page (falls back to the
   full list in `wofi` when several/none match; `:1pass <text>` filters by
   title/URL instead and skips the picker when only one remains);

1. lists Login items via `op item list --categories Login --format json`;
2. preselects the items whose URL matches the current page (falls back to the
   full list in `wofi` when several/none match);
3. fills the visible username/email and password inputs (native value setter +
   `input`/`change` events, so React/Vue forms accept it);
4. copies the password to the clipboard, and the TOTP code (if the item has
   one) afterwards;
5. reports the result via `message-info` / `message-error`.

`op` authenticates through the desktop app (biometric/polkit), so no master
password is passed on the command line.

## Google sign-in

Google refuses OAuth/account sign-in from QtWebEngine-based browsers
(qutebrowser issues #5182, #8492): the page errors out or claims the browser is
insecure. qutebrowser ships a `ua-google` site-specific quirk, but Google
periodically starts rejecting the pinned version, so this module overrides the
User-Agent for `https://accounts.google.com/*` and
`https://accounts.youtube.com/*` with `googleSignInFix.userAgent`
(default a current Firefox UA). Only those patterns are affected.

`[object Object]` in a site's error message is the site stringifying a JS error
object — it is the *site's* generic handler, not the real Google error. Get the
real error from the page console (`:devtools`, or `:jseval`).

## Files

| File | Purpose |
|---|---|
| `default.nix` | import manifest |
| `options.nix` | `my.programs.qutebrowser.*` options |
| `config.nix` | package, `config.py`, userscript install |
| `lib.nix` | config.py fragment shared with the proxy profile |
| `tests.nix` | assertions |
| `meta.nix` | module metadata |
| `userscripts/qute-1pass.py` | the 1Password userscript |

## Gotchas

* Without `--basedir`, qutebrowser's config dir is `~/.config/qutebrowser`, so
  `config.py` belongs at its **root**. With `--basedir X` it is
  `X/config/config.py` (see `GOTCHAS.md`).
* `config.py` here is a read-only home-manager symlink — `:config-write-py`
  replaces it and breaks the link. Use `:set` (writes `autoconfig.yml`) for
  per-machine overrides.
* The ephemeral `proxy-browser` alias (`--basedir /tmp/proxy-session`) has no
  `config.py`, so the 1Password binding is only available in the persistent
  profile (`proxy-browser-persist` / the "Proxy Browser" app entry).
