{ config, lib, ... }:

let
  cfg = config.my.nixpkgs.buildWorkarounds;

  # inline-snapshot keeps `doCheck = false`: its broken tests are not named in
  # nixpkgs's `disabledTests`, so appending to that list would leave them
  # running and the build would still fail. The other package skips tests by
  # name so that only the two broken cases are dropped and the remaining
  # ~2589 still execute.
  inlineSnapshotOverlay =
    final: prev: {
      pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
        (pyfinal: pyprev: {
          inline-snapshot = pyprev.inline-snapshot.overridePythonAttrs (old: {
            doCheck = false;
          });
        })
      ];
    };

  anyioOverlay =
    final: prev: {
      pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
        (pyfinal: pyprev: {
          anyio = pyprev.anyio.overridePythonAttrs (old: {
            disabledTests = (old.disabledTests or [ ]) ++ [
              "test_tls_connectable"
              "test_cancelled_after_acquire"
            ];
          });
        })
      ];
    };
in
{
  # `lib.mkMerge` rather than an attrset `//` merge: the latter would force
  # this module's own `config` while `config` is still being assembled, which
  # recurses infinitely under nixos-unified's transposition pass. `mkMerge`
  # keeps both sides lazy.
  config = lib.mkMerge [
    { nixpkgs.overlays = lib.optionals cfg.inlineSnapshot [ inlineSnapshotOverlay ]; }
    { nixpkgs.overlays = lib.optionals cfg.anyio [ anyioOverlay ]; }
  ];
}
