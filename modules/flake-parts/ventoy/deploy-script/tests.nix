{ pkgs, lib }:
let
  minimalInputs = {
    ventoyJson = pkgs.writeText "ventoy.json" ''
      { "control": [{"VTOY_DEFAULT_SEARCH_ROOT": "/iso"}] }
    '';
    isoMappings = [ ];
    fileMappings = [ ];
    device = "";
    mountPoint = "/mnt/ventoy";
    buildInstallerIso = false;
    secureBoot = false;
    gpt = false;
    label = "Ventoy";
  };

  deployScript = pkgs.callPackage ./. minimalInputs;

  # Test 1: Derivation builds with minimal inputs
  test-builds = pkgs.runCommand "test-ventoy-deploy-builds" {
    buildInputs = [ deployScript ];
  } ''
    # Verify the binary was created and is executable
    if [[ -x "${deployScript}/bin/ventoy-deploy" ]]; then
      echo "PASS: ventoy-deploy binary found and executable"
    else
      echo "FAIL: ventoy-deploy binary missing or not executable" >&2
      exit 1
    fi
    # Verify the script sources ventoy-deploy.sh
    if grep -q "ventoy-deploy.sh" "${deployScript}/bin/ventoy-deploy"; then
      echo "PASS: script sources ventoy-deploy.sh"
    else
      echo "FAIL: script does not source ventoy-deploy.sh" >&2
      exit 1
    fi
    touch "$out"
  '';

  # Test 2: Missing VENTOY_JSON causes non-zero exit
  test-missing-ventoy-json = pkgs.runCommand "test-ventoy-deploy-missing-ventoy-json" {
    buildInputs = [ deployScript ];
  } ''
    set +e
    output=$(VENTOY_JSON="" ${deployScript}/bin/ventoy-deploy --help 2>&1)
    rc=$?
    set -e
    if [[ $rc -ne 0 ]]; then
      echo "PASS: empty VENTOY_JSON causes exit $rc"
    else
      echo "FAIL: expected non-zero exit, got $rc" >&2
      exit 1
    fi
    touch "$out"
  '';

  # Test 3: Help flag works when inputs are valid
  test-help-exits-zero = pkgs.runCommand "test-ventoy-deploy-help" {
    buildInputs = [ deployScript ];
  } ''
    set +e
    output=$(${deployScript}/bin/ventoy-deploy --help 2>&1)
    rc=$?
    set -e
    if [[ $rc -eq 0 ]]; then
      echo "PASS: --help exits 0"
    else
      echo "FAIL: --help exited $rc" >&2
      exit 1
    fi
    if echo "$output" | grep -q "Usage: ventoy-deploy"; then
      echo "PASS: usage text printed"
    else
      echo "FAIL: usage text not found in output" >&2
      exit 1
    fi
    touch "$out"
  '';

in
pkgs.runCommand "ventoy-deploy-tests" { } ''
  echo "=== ventoy-deploy test suite ==="
  echo ""

  echo "[Test 1] Minimal inputs build"
  cat ${test-builds}
  echo ""

  echo "[Test 2] Missing VENTOY_JSON detected"
  cat ${test-missing-ventoy-json}
  echo ""

  echo "[Test 3] --help works"
  cat ${test-help-exits-zero}
  echo ""

  echo "All tests passed."
  touch "$out"
''
