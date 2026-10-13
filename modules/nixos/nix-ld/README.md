# nix-ld

Runs **unpatched dynamic ELF binaries** on NixOS by linking
`/lib64/ld-linux-x86-64.so.2` to nix-ld instead of NixOS' stub-ld shim.

## Why this exists

NixOS cannot exec a binary built for a generic Linux distro out of the box:
there is no `/lib64/ld-linux-x86-64.so.2`, so the ELF interpreter resolves to
**stub-ld**, a shim that just prints

```
Could not start dynamically linked executable: <path> … stub-ld
```

That is not a hypothetical — it breaks Zed on this machine:

* Zed downloads its own generic-Linux `node` to
  `~/.local/share/zed/node/node-*/bin/node` when no system `node` is on PATH.
  Stub-ld → **bash-language-server / json-language-server never start**.
* Any Zed language server that ships as a native binary (e.g. `ruff`) hits the
  same wall the first time it launches — a freshly downloaded
  `~/.local/share/zed/languages/ruff/ruff-*/ruff` has
  `INTERP = /lib64/ld-linux-x86-64.so.2`, so it goes through stub-ld.
* `programs.nix-ld` fixes all of them at once, plus future downloads, in every
  project — no devShell changes, no per-server binary paths.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `my.system.nix-ld.enable` | `false` | Install the nix-ld loader and library set |
| `my.system.nix-ld.libraries` | `[ ]` | Libraries **appended** to nixpkgs' default set |

## Usage

```nix
my.system.nix-ld.enable = true;
```

## Notes

- Default libraries (from nixpkgs) cover the binaries this repo actually runs
  today: Zed's downloaded Node 24, `ruff`, and the node-based language
  servers. Nothing extra was needed. Verified **before** switching, using the
  real built library path from this module on `ld.so --library-path`:
  Zed's `node-v24.11.0-linux-x64` prints `v24.11.0`, a stock (unpatched) `ruff`
  prints `ruff 0.17.0`, and both bash-language-server and
  vscode-json-language-server answer an LSP `initialize` handshake.
  (`readelf -d` alone is not enough: node/ruff ask for `libc.so.6`,
  `libm.so.6`, `libdl.so.2`, … which are *not* in the library set — the loader
  resolves those from its own glibc.)
- `my.system.nix-ld.libraries` is **additive**: `programs.nix-ld.libraries`
  is a list option, so host entries join nixpkgs' default set rather than
  replacing it. `tests.nix` asserts the defaults stay present — an
  `mkForce`-style override fails evaluation instead of silently breaking the
  binaries that already work.
- Only enable it where you need it. It adds a system package and the
  `ld-library-path` closure (`/run/current-system/sw/share/nix-ld/lib`) to the
  host, which is dead weight on a minimal/headless box.
- `my.system.nix-ld` works **without** `NIX_LD` / `NIX_LD_LIBRARY_PATH` being
  set: those live in `environment.sessionVariables`, so they only reach
  sessions started *after* the switch, and nix-ld falls back to its built-in
  default (`/run/current-system/sw/share/nix-ld/lib`) when they are absent.
  Verified on desktop by running Zed's own downloaded `node` and a stock
  `ruff` with both variables unset. Same staleness trap the Houdini module
  already works around for `HOUDINI_PACKAGE_DIR`
  (`modules/nixos/houdini/config.nix`) — a GUI session started before the
  rebuild simply has no `NIX_LD`.

## Related

- Enabled on `desktop` and `laptop` (the hosts that run Zed).
- Zed's module: [`modules/home/zed-editor`](../home/zed-editor/README.md).
