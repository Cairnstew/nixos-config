{ config, lib, ... }:

# ─────────────────────────────────────────────────────────────────────────────
# my.testing — flake-parts module that generates per-host test packages.
#
# What it does:
#   • For every NixOS / nix-darwin / Home-Manager config that matches the
#     current build system it creates a package named test-<hostName>.
#   • It also creates a single `test` runner CLI:
#       nix run .#test -- list
#       nix run .#test -- run   [HOST]
#       nix run .#test -- dry-run [HOST]
#       nix run .#test -- show  [HOST]
# ─────────────────────────────────────────────────────────────────────────────

let
  cfg = config.my.testing;

  # ── helpers (pure functions, no pkgs required) ─────────────────────────

  /* Check whether a NixOS or nix-darwin config targets the build system */
  matchesSystem = system: nixosCfg:
    let
      probed = builtins.tryEval nixosCfg.config.nixpkgs.hostPlatform.system;
    in
      probed.success && probed.value == system;

  /* Run the user-supplied extra check functions against a host. */
  runExtraChecks = arg:
    map (fn: fn arg) cfg.extraChecks;

  /* Turn extra-check results into shell script fragments. */
  extraCheckScript = results:
    lib.concatMapStrings (result: ''
      echo "  [Extra] ${result.message}: $([ ${lib.boolToString result.pass} = true ] && echo 'PASS' || echo 'FAIL')"
      ${lib.optionalString (!result.pass) "exit_code=1"}
    '') results;

in
{
  options.my.testing = {
    extraChecks = lib.mkOption {
      type = lib.types.listOf lib.types.raw;
      default = [];
      description = ''
        Extra check functions to run against each host.
        Each function receives an attrset with keys:
        `{ hostname, system, pkgs, config }` and returns an attrset
        `{ pass :: bool, message :: string }`.
      '';
      example = lib.literalExpression ''
        [
          (host: {
            pass = host.config.my.services.tailscale.enable ->
                     lib.fileExists "''${pkgs.tailscale}/bin/tailscale";
            message = "tailscale binary in closure";
          })
        ]
      '';
    };
  };

  config = {
    perSystem = { self', system, pkgs, ... }:
      let

        # ── per-host test package generators (need pkgs) ─────────────────

        /* Produce a test script for a NixOS / nix-darwin system closure. */
        mkSystemTestPackage = hostType: hostname: systemCfg:
          let
            toplevel = systemCfg.config.system.build.toplevel;
            extraResults = runExtraChecks {
              inherit hostname pkgs;
              system = systemCfg;
              config = systemCfg.config;
            };
          in
          pkgs.writeShellApplication {
            name = "test-${hostname}";
            runtimeInputs = with pkgs; [ bash coreutils findutils gnugrep gawk ];
            text = ''
              set -euo pipefail
              SYSTEM_ROOT="${toplevel}"

              echo "=== ${hostType} test suite: ${hostname} ==="
              echo "System closure: $SYSTEM_ROOT"
              echo ""

              exit_code=0

              # ── L0: Closure integrity ──────────────────────────────────
              echo "[L0] Checking system closure integrity..."
              # NixOS closures have: bin, etc, sw, systemd (plus kernel
              # artefacts).  /lib, /sbin, /nix, /store are created at
              # activation time and do not exist in the raw toplevel.
              for path in bin etc sw systemd; do
                if [ ! -e "$SYSTEM_ROOT/$path" ]; then
                  echo "  FAIL: /$path missing from system closure"
                  exit_code=1
                else
                  echo "  OK: /$path present"
                fi
              done

              # ── L1: systemd unit declarations ──────────────────────────
              # NixOS stores unit files in sw/lib/systemd/system/ inside the
              # closure.  etc/systemd/system is a runtime symlink that only
              # exists on an activated system.
              systemd_dir=""
              for candidate in "$SYSTEM_ROOT/sw/lib/systemd/system" "$SYSTEM_ROOT/etc/systemd/system"; do
                if [ -d "$candidate" ]; then
                  systemd_dir="$candidate"
                  break
                fi
              done

              if [ -n "$systemd_dir" ]; then
                echo ""
                echo "[L1] Checking systemd units (from $systemd_dir)..."
                unit_count=$(find "$systemd_dir" -type f \( -name "*.service" -o -name "*.timer" -o -name "*.socket" \) 2>/dev/null | wc -l)
                echo "  Found $unit_count service/timer/socket units"

                while IFS= read -r -d "" unit_file; do
                  if grep -q "^ExecStart=" "$unit_file" 2>/dev/null; then
                    exec_start=$(grep "^ExecStart=" "$unit_file" | head -1 | cut -d= -f2-)
                    # Skip systemd special prefixes: @, !, !@
                    if [[ "$exec_start" != "@"* && "$exec_start" != "!"* && "$exec_start" != "!@"* && -n "$exec_start" ]]; then
                      binary=$(echo "$exec_start" | awk '{print $1}')
                      # Check in the closure *or* as an absolute path on the builder
                      if [ ! -e "$SYSTEM_ROOT$binary" ] && [ ! -e "$binary" ]; then
                        echo "  WARN: ExecStart binary not in closure: $binary (in $(basename "$unit_file"))"
                      fi
                    fi
                  fi
                done < <(find "$systemd_dir" -name "*.service" -print0 2>/dev/null)
                echo "  OK: systemd unit check complete"
              fi

              # ── L2: Environment sanity ───────────────────────────────
              echo ""
              echo "[L2] Smoke testing environment..."
              if [ -f "$SYSTEM_ROOT/etc/nixos/configuration.nix" ] || [ -f "$SYSTEM_ROOT/etc/nixos/hardware-configuration.nix" ]; then
                echo "  OK: NixOS config files present in closure"
              else
                echo "  INFO: No standard NixOS config files in closure (may be expected)"
              fi

              if [ -d "$SYSTEM_ROOT/etc/profile.d" ]; then
                env_files=$(find "$SYSTEM_ROOT/etc/profile.d" -type f -name "*.sh" | wc -l)
                echo "  Found $env_files profile.d scripts"
              fi

              # ── L3: Broken symlinks ──────────────────────────────────
              echo ""
              echo "[L3] Checking for broken symlinks..."
              broken=$(find "$SYSTEM_ROOT" -xtype l 2>/dev/null | head -20)
              if [ -n "$broken" ]; then
                broken_count=$(echo "$broken" | wc -l)
                echo "  WARN: Found $broken_count broken symlinks:"
                echo "$broken" | head -10 | sed 's/^/    /'
              else
                echo "  OK: No broken symlinks found"
              fi

              ${extraCheckScript extraResults}

              echo ""
              echo "=== ${hostname}: $([ $exit_code -eq 0 ] && echo 'PASS' || echo 'FAIL') ==="
              exit $exit_code
            '';
          };

        /* Produce a test script for a Home-Manager activation package. */
        mkHomeTestPackage = name: homeCfg:
          let
            activationPackage = homeCfg.activationPackage;
            extraResults = runExtraChecks {
              hostname = name;
              system   = homeCfg;
              inherit pkgs;
              config   = homeCfg.config;
            };
          in
          pkgs.writeShellApplication {
            name = "test-${name}";
            runtimeInputs = with pkgs; [ bash coreutils findutils ];
            text = ''
              set -euo pipefail
              HOME_ROOT="${activationPackage}"

              echo "=== Home Manager test suite: ${name} ==="
              echo "Activation package: $HOME_ROOT"
              echo ""

              exit_code=0

              # ── L0: Package integrity ──────────────────────────────────
              echo "[L0] Checking activation package integrity..."
              for path in home-files; do
                if [ ! -e "$HOME_ROOT/$path" ]; then
                  echo "  FAIL: /$path missing from activation package"
                  exit_code=1
                else
                  echo "  OK: /$path present"
                fi
              done

              # ── L1: Broken symlinks ──────────────────────────────────
              echo ""
              echo "[L1] Checking for broken symlinks..."
              broken=$(find "$HOME_ROOT/home-files" -xtype l 2>/dev/null | head -20)
              if [ -n "$broken" ]; then
                broken_count=$(echo "$broken" | wc -l)
                echo "  WARN: Found $broken_count broken symlinks:"
                echo "$broken" | head -10 | sed 's/^/    /'
              else
                echo "  OK: No broken symlinks found"
              fi

              ${extraCheckScript extraResults}

              echo ""
              echo "=== ${name}: $([ $exit_code -eq 0 ] && echo 'PASS' || echo 'FAIL') ==="
              exit $exit_code
            '';
          };

        # ── collect all hosts for the current build system ───────────────

        mkHostEntries =
          let
            # 1. Define a list of hostnames you want to skip
            disabledHosts = [ ];

            # 2. Helper function to filter out disabled hosts
            isTestable = name: _: ! (builtins.elem name disabledHosts);

            # 3. Apply the filter to your configurations
            nixosCfgs   = lib.filterAttrs isTestable 
                            (lib.filterAttrs (_: matchesSystem system) config.flake.nixosConfigurations);
            darwinCfgs  = lib.filterAttrs isTestable 
                            (lib.filterAttrs (_: matchesSystem system) (config.flake.darwinConfigurations or {}));
            homeCfgs    = lib.filterAttrs isTestable 
                            (lib.filterAttrs (_: homeCfg:
                              let probed = builtins.tryEval homeCfg.config.home.homeDirectory;
                              in probed.success
                            ) (config.flake.homeConfigurations or {}));
          in
            # Each entry: { name :: string; type :: "nixos" | "darwin" | "home"; package :: drv; }
            (lib.mapAttrsToList (n: c: { name = n; type = "nixos";  package = mkSystemTestPackage "NixOS" n c; }) nixosCfgs)
            ++ (lib.mapAttrsToList (n: c: { name = n; type = "darwin"; package = mkSystemTestPackage "nix-darwin" n c; }) darwinCfgs)
            ++ (lib.mapAttrsToList (n: c: { name = n; type = "home";   package = mkHomeTestPackage n c; }) homeCfgs);

        # ── test-runner CLI generator ────────────────────────────────────

        mkTestRunner = hostEntries:
          let
            hostNames = map (e: e.name) hostEntries;

            mkDryRunCases = lib.concatMapStrings
              ({ name, type, ... }:
                let
                  flakePath = if type == "home" then
                                ".#homeConfigurations.${name}.activationPackage"
                              else
                                ".#${type}Configurations.${name}.config.system.build.toplevel";
                in ''
                  ${name})
                    if [ -n "$verbose_flag" ]; then
                      nix build "${flakePath}" --no-link --print-build-logs --verbose
                    else
                      nix build "${flakePath}" --no-link --print-build-logs
                    fi
                    ;;
                '')
              hostEntries;

            mkShowCases = lib.concatMapStrings
              ({ name, type, ... }:
                let
                  flakePath = if type == "home" then
                                ".#homeConfigurations.${name}.activationPackage.outPath"
                              else
                                ".#${type}Configurations.${name}.config.system.build.toplevel";
                in ''
                  ${name})
                    nix eval "${flakePath}" --raw
                    ;;
                '')
              hostEntries;

            mkDryRunAllCases = lib.concatMapStrings
              ({ name, type, ... }:
                let
                  flakePath = if type == "home" then
                                ".#homeConfigurations.${name}.activationPackage"
                              else
                                ".#${type}Configurations.${name}.config.system.build.toplevel";
                in ''
                  ${name})
                    if [ -n "$verbose_flag" ]; then
                      nix build "${flakePath}" --no-link --verbose 2>&1 || true
                    else
                      nix build "${flakePath}" --no-link 2>&1 || true
                    fi
                    ;;
                '')
              hostEntries;
          in
          pkgs.writeShellApplication {
            name = "test";
            runtimeInputs = with pkgs; [ bash coreutils gnugrep nix ];
            text = ''
              set -euo pipefail

              usage() {
                cat <<EOF
              Usage: test [COMMAND] [OPTIONS]

              Commands:
                list              List all available host configurations
                summary           Show brief summary of each host
                run   [HOST]      Run test suite for all hosts or a specific one
                dry-run [HOST]    Evaluate config without building
                show  [HOST]      Show evaluated configuration store path

              Options:
                --help, -h        Show this help
                --verbose, -v     Pass --verbose to underlying nix commands
              EOF
              }

              HOSTS="${lib.concatStringsSep " " hostNames}"

              if [ $# -eq 0 ]; then
                usage
                exit 0
              fi

              cmd="''${1:-}"; shift || true
              verbose=false
              target_host=""

              while [ $# -gt 0 ]; do
                case "$1" in
                  --verbose|-v) verbose=true; shift ;;
                  --help|-h)    usage; exit 0 ;;
                  --all)        shift ;;
                  *)            target_host="$1"; shift ;;
                esac
              done

              verbose_flag=""
              [ "$verbose" = true ] && verbose_flag="--verbose"

              case "$cmd" in
                list)
                  echo "Available host configurations:"
                  echo ""
                  for h in $HOSTS; do
                    echo "  $h"
                  done
                  echo ""
                  host_count=$(echo "$HOSTS" | wc -w)
                  echo "Total: $host_count hosts"
                  ;;

                summary)
                  echo "Host configuration summary:"
                  echo ""
                  for h in $HOSTS; do
                    echo "  $h → test-$h"
                  done
                  echo ""
                  echo "Run tests:  nix run .#test run [HOST]"
                  echo "Dry-run:    nix run .#test dry-run [HOST]"
                  echo "Show path:  nix run .#test show [HOST]"
                  if [ -n "$HOSTS" ]; then
                    echo ""
                    first_host=$(echo "$HOSTS" | awk '{print $1}')
                    echo "Example:    nix run .#test run $first_host"
                  fi
                  ;;

                run)
                  if [ -n "$target_host" ]; then
                    if ! echo "$HOSTS" | grep -qw "$target_host"; then
                      echo "Error: unknown host '$target_host'"
                      echo "Available: $HOSTS"
                      exit 1
                    fi
                    echo "Running test for: $target_host"
                    exec nix run ".#test-$target_host"
                  else
                    echo "Running tests for all hosts..."
                    echo ""
                    all_pass=true
                    for h in $HOSTS; do
                      echo ""
                      echo ">>> Testing: $h"
                      echo "-----------------------------------"
                      if ! nix run ".#test-$h"; then
                        all_pass=false
                      fi
                    done
                    echo ""
                    echo "==================================="
                    if $all_pass; then
                      echo "All hosts passed."
                    else
                      echo "Some hosts failed. See above."
                      exit 1
                    fi
                  fi
                  ;;

                dry-run)
                  if [ -n "$target_host" ]; then
                    if ! echo "$HOSTS" | grep -qw "$target_host"; then
                      echo "Error: unknown host '$target_host'"
                      echo "Available: $HOSTS"
                      exit 1
                    fi
                    echo "Evaluating configuration for: $target_host"
                    case "$target_host" in
                      ${mkDryRunCases}
                      *)
                        echo "Error: failed to resolve flake path for '$target_host'"
                        exit 1
                        ;;
                    esac
                  else
                    echo "Evaluating all host configurations..."
                    for h in $HOSTS; do
                      echo "Evaluating: $h"
                      case "$h" in
                        ${mkDryRunAllCases}
                        *)
                          echo "  WARN: unknown host '$h'"
                          ;;
                      esac
                    done
                    echo ""
                    echo "Evaluation pass complete."
                  fi
                  ;;

                show)
                  if [ -z "$target_host" ]; then
                    echo "Error: 'show' requires a HOST argument"
                    echo "Usage: test show <host>"
                    exit 1
                  fi
                  if ! echo "$HOSTS" | grep -qw "$target_host"; then
                    echo "Error: unknown host '$target_host'"
                    echo "Available: $HOSTS"
                    exit 1
                  fi
                  case "$target_host" in
                    ${mkShowCases}
                    *)
                      echo "Error: failed to resolve flake path for '$target_host'"
                      exit 1
                      ;;
                  esac
                  ;;

                *)
                  echo "Error: unknown command '$cmd'"
                  echo ""
                  usage
                  exit 1
                  ;;
              esac
            '';
          };

      in
      {
        packages = {
          test = (mkTestRunner (mkHostEntries));
        } // lib.listToAttrs (map (e: { name = "test-${e.name}"; value = e.package; }) (mkHostEntries));
      };
  };
}
