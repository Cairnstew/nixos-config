{ lib, ... }:
{
  options.my.nixpkgs.buildWorkarounds = {
    inlineSnapshot = lib.mkOption {
      type = lib.types.bool;
      # Default true, unlike the sibling toggle below, because the two
      # overrides have genuinely different cache economics. Verified at the
      # 2026-09-19 nixpkgs pin: stock inline-snapshot-0.34.2 is 404 on
      # cache.nixos.org, so it is built from source either way and the
      # override costs no substitutability — while *not* overriding makes the
      # build fail, because 3 of its 1402 tests fail in the sandbox. It is a
      # dependency of fastapi → openapi-core → jupyterlab-server →
      # jupyter.service. Turn it off only if a pin makes the stock variant
      # substitutable again, and re-check `nix build --dry-run` counts first.
      default = true;
      defaultText = lib.literalExpression "true";
      description = ''
        Skip inline-snapshot's test suite. 3 of 1402 tests fail in the Nix
        sandbox (snapshot write-back + codegen tests that exercise file I/O).

        The override targets `doCheck` rather than naming individual tests,
        because upstream nixpkgs does not pin a stable list of the broken
        test names for this package.
      '';
    };

    anyio = lib.mkOption {
      type = lib.types.bool;
      # Default false: unlike inline-snapshot, anyio's stock variant *is*
      # substitutable on a mature pin, and any override changes the
      # derivation hash, losing that hit for anyio and everything downstream
      # of it (httpx, starlette → fastapi/jupyter). Measured on desktop at
      # the 2026-09-19 pin: enabling this took the toplevel from 42 to 278
      # derivations and 1.1 GiB to 4.3 GiB of downloads, for nothing —
      # substitution never runs the test suite.
      default = false;
      defaultText = lib.literalExpression "false";
      description = ''
        Skip the two test cases anyio 4.14.2 fails in the Nix sandbox,
        leaving the other ~2589 running:

          tests/streams/test_tls.py::test_tls_connectable
            → ValueError: server_hostname can only be specified in client mode
          tests/test_synchronization.py::TestLock::test_cancelled_after_acquire
            → ExceptionGroup: multiple unraisable exception warnings

        Both are fallout from the TLSStream connect refactor in 4.14.2 — the
        same change that fixed CVE-2026-63374 (CVSS 9.3, TLS certificate
        spoofing via IDNA 2003 hostname encoding in connect_tcp() and
        TLSStream.wrap()).

        DO NOT resolve this by pinning anyio < 4.14.2: that reintroduces the
        CVE, so downgrading is not an available workaround.

        Enable this only in response to a real from-source anyio build
        failure — typically right after bumping to a fresh nixpkgs pin whose
        packages are not yet on cache.nixos.org. Revert it once the cache has
        caught up, and verify with `nix build --dry-run` that the derivation
        count drops.
      '';
    };
  };
}
