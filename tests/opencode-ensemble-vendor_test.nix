# Hash-guard for the vendored opencode-ensemble artifact
# (modules/home/opencode/vendor/opencode-ensemble-*-dist.js).
#
# The dist is a pre-built copy of Cairnstew/opencode-ensemble, NOT source for
# this repo. The ONLY legitimate update path is:
#   1. develop the change upstream via the ensemble space
#      (team_spawn(name="fix", space="ensemble", worktree=false, ...)),
#   2. re-vendor with tools/revendor-opencode-ensemble.sh <dist> <version>
#      (which rewrites the recorded hash in the same operation).
# A local edit to the bundle — the brute-force failure mode this guard exists
# to catch — produces a hash mismatch and fails loudly here.
#
# The recorded hash lives in vendor/opencode-ensemble.sha256 (next to the
# artifact, regenerated only by the re-vendor script), NOT as a literal in
# this test, so a legitimate update has no separate manual hash-edit step to
# forget or fake.
{ pkgs, lib, ... }:
let
  vendorDir = ../modules/home/opencode/vendor;

  # Parse vendor/opencode-ensemble.sha256 (skip # comments / blank lines).
  hashLines = lib.filter
    (l: l != "" && !(lib.hasPrefix "#" l))
    (lib.splitString "\n" (builtins.readFile "${vendorDir}/opencode-ensemble.sha256"));
  parseKV = l:
    let kv = lib.splitString "=" l;
    in {
      key = builtins.elemAt kv 0;
      value = builtins.elemAt kv 1;
    };
  kv = map parseKV hashLines;
  get = key: lib.head (map (e: e.value) (lib.filter (e: e.key == key) kv));
  recordedName = get "filename";
  recordedSha = get "sha256";

  # Every opencode-ensemble-*-dist.js in the vendor dir; the record must name
  # exactly the current one (a stale record means the re-vendor script wasn't
  # used — fail so it is).
  allDistFiles = lib.filter
    (n: lib.hasPrefix "opencode-ensemble-" n && lib.hasSuffix "-dist.js" n)
    (lib.attrNames (builtins.readDir vendorDir));
in
{
  suites."opencode-ensemble-vendor-guard" = {
    pos = __curPos;
    tests = [
      {
        name = "vendored-dist-unchanged-or-revendored";
        type = "script";
        script = ''
          set -euo pipefail
          vendor_dir='${vendorDir}'
          recorded_name='${recordedName}'
          recorded_sha='${recordedSha}'
          all_dists='${lib.concatStringsSep " " allDistFiles}'

          # Exactly one dist may be present, and it must be the recorded one.
          count=0
          for d in $all_dists; do count=$((count + 1)); done
          if [ "$count" -ne 1 ]; then
            echo "ERROR: vendor/ must contain exactly one opencode-ensemble-*-dist.js (found: $all_dists)." >&2
            echo "A stale/extra artifact means the re-vendor script was not used." >&2
            echo "Fix: run tools/revendor-opencode-ensemble.sh <dist> <version> (see modules/home/opencode/FORK.md)." >&2
            exit 1
          fi
          dist_file="$vendor_dir/$all_dists"
          [ "$all_dists" = "$recorded_name" ] || {
            echo "ERROR: vendored artifact ($all_dists) does not match the recorded filename ($recorded_name)." >&2
            echo "Regenerate via tools/revendor-opencode-ensemble.sh — never edit vendor files by hand." >&2
            exit 1
          }

          # Hash the committed bytes and compare to the record.
          actual=$(${pkgs.python3}/bin/python3 - "$dist_file" <<'PYEOF'
          import hashlib, sys
          print(hashlib.sha256(open(sys.argv[1], "rb").read()).hexdigest())
          PYEOF
          )
          if [ "$actual" != "$recorded_sha" ]; then
            echo "ERROR: vendored opencode-ensemble artifact has a local modification (hash mismatch)." >&2
            echo "  recorded: $recorded_sha ($recorded_name)" >&2
            echo "  actual:   $actual" >&2
            echo "opencode-ensemble is vendored — develop in the ensemble space, re-vendor per modules/home/opencode/FORK.md." >&2
            echo "  team_spawn(name=\"fix\", space=\"ensemble\", worktree=false, prompt=\"...\")" >&2
            echo "  tools/revendor-opencode-ensemble.sh <dist> <version>" >&2
            exit 1
          fi
          echo "ok: vendored artifact ($recorded_name) matches recorded hash ($recorded_sha)"
        '';
      }
    ];
  };
}