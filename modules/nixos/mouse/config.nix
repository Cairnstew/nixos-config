{ config, lib, pkgs, flake, ... }:
let
  cfg = config.my.hardware.mouse;
  inherit (flake) inputs;
  maccelBin = "${maccel-cli}/bin/maccel";

  # ── maccel CLI binary (built from the flake input) ──────────────────────
  maccel-cli = pkgs.rustPlatform.buildRustPackage {
    pname = "maccel-cli";
    version = (builtins.fromTOML (builtins.readFile "${inputs.maccel}/cli/Cargo.toml")).package.version;
    src = inputs.maccel;
    cargoLock.lockFile = "${inputs.maccel}/Cargo.lock";
    cargoBuildFlags = [ "--bin" "maccel" ];
    doCheck = false;
  };

  # Maps Nix option names to maccel CLI param names for runtime apply.
  paramNameMap = {
    sensMultiplier = "sens-mult";
    yxRatio = "yx-ratio";
    inputDpi = "input-dpi";
    angleRotation = "angle-rotation";
    acceleration = "accel";
    offset = "offset-linear";
    outputCap = "output-cap";
    decayRate = "decay-rate";
    limit = "limit";
    gamma = "gamma";
    smooth = "smooth";
    motivity = "motivity";
    syncSpeed = "sync-speed";
  };

  # Build the set of commands to apply all configured params at runtime.
  applyParamsCmds =
    let
      p = config.hardware.maccel.parameters;
      setParam = nixName: cliName:
        lib.optional (builtins.getAttr nixName p != null)
          "${maccelBin} set param ${cliName} ${toString (builtins.getAttr nixName p)}";
      paramCmds = lib.flatten (lib.mapAttrsToList setParam paramNameMap);
    in
    [ "${maccelBin} set mode ${p.mode}" ] ++ paramCmds;

  # ── Expected values (from Nix config) embedded for runtime comparison ──
  expectedParams = cfg.parameters;

  # Build a string of expected param values for embedding in the watch script.
  # Format: "sens-mult=1.0 yx-ratio=null input-dpi=null ..."
  mkExpectedStr = lib.concatStringsSep " " (
    lib.mapAttrsToList
      (nixName: cliName:
        "${cliName}=${builtins.toString (builtins.getAttr nixName expectedParams)}"
      )
      paramNameMap
  );

  # ── maccel-watch: interactive monitoring helper ────────────────────────
  maccelWatch = pkgs.writeShellScriptBin "maccel-watch" ''
    set -euo pipefail

    MACCEL="${maccelBin}"
    EXPECTED_MODE="${modeDisplayMap.${expectedParams.mode}}"
    EXPECTED="${mkExpectedStr}"

    usage() {
      echo "Usage: maccel-watch [OPTION]"
      echo "Monitor maccel kernel module state."
      echo ""
      echo "  -d, --diff     Show differences from configured expected values"
      echo "  -w, --watch    Continuous monitoring (repeated every N seconds, default 2)"
      echo "  -n <sec>       Refresh interval for --watch (default 2)"
      echo "  -j, --json     JSON output (machine-readable)"
      echo "  -h, --help     Show this help"
      exit 0
    }

    # ── helpers ──────────────────────────────────────────────────────────
    red()   { printf "\033[31m%s\033[0m\n" "$*"; }
    green() { printf "\033[32m%s\033[0m\n" "$*"; }
    yellow(){ printf "\033[33m%s\033[0m\n" "$*"; }
    bold()  { printf "\033[1m%s\033[0m" "$*"; }

    get_mode() {
      $MACCEL get mode 2>/dev/null | head -1 | tr -d '\n'
    }

    get_param() {
      $MACCEL get param "$1" 2>/dev/null || echo "ERR"
    }

    json_escape() {
      printf '%s' "$1" | sed 's/"/\\"/g'
    }

    parse_expected() {
      # Parse the EXPECTED string into a format we can compare
      echo "$EXPECTED"
    }

    # Parse expected values into associative array
    declare -A EXP
    for pair in $EXPECTED; do
      key="''${pair%%=*}"
      val="''${pair#*=}"
      EXP["$key"]="$val"
    done

    # ── diff mode ────────────────────────────────────────────────────────
    do_diff() {
      local mode exit_code=0
      mode=$(get_mode)
      echo "maccel status — $(bold "mode: $mode")"
      echo ""

      # Compare mode
      if [ "$mode" != "$EXPECTED_MODE" ]; then
        red "  mode: $mode  (expected: $EXPECTED_MODE)  ✗"
        exit_code=1
      else
        green "  mode: $mode  ✓"
      fi
      echo ""

      # Compare all params that have an expected value
      for cli_name in "''${!EXP[@]}"; do
        local expected="''${EXP[$cli_name]}"
        local actual
        actual=$(get_param "$cli_name")

        if [ "$expected" = "null" ]; then
          continue
        fi

        if [ "$actual" != "$expected" ]; then
          red "  $cli_name: $actual  (expected: $expected)  ✗"
          exit_code=1
        else
          green "  $cli_name: $actual  ✓"
        fi
      done

      return $exit_code
    }

    # ── full state dump ──────────────────────────────────────────────────
    do_show() {
      local mode
      mode=$(get_mode)
      echo "maccel status — $(bold "mode: $mode")"
      echo ""

      # Show all sysfs params
      if [ -d /sys/module/maccel/parameters ]; then
        for f in /sys/module/maccel/parameters/*; do
          local name value
          name=$(basename "$f")
          value=$(cat "$f" 2>/dev/null || echo "N/A")
          printf "  %-20s %s\n" "$name:" "$value"
        done
      else
        yellow "  kernel module not loaded (no /sys/module/maccel/parameters)"
      fi
    }

    # ── JSON output ──────────────────────────────────────────────────────
    do_json() {
      local mode
      mode=$(get_mode)
      printf '{"mode":"%s","params":{' "$mode"
      local first=1
      if [ -d /sys/module/maccel/parameters ]; then
        for f in /sys/module/maccel/parameters/*; do
          local name value
          name=$(basename "$f")
          value=$(cat "$f" 2>/dev/null || echo "N/A")
          [ "$first" = "0" ] && printf ","
          first=0
          printf '"%s":"%s"' "$(json_escape "$name")" "$(json_escape "$value")"
        done
      fi
      printf '},"expected_mode":"%s"}' "$EXPECTED_MODE"
      echo ""
    }

    # ── main ─────────────────────────────────────────────────────────────
    MODE="show"
    INTERVAL=2

    while [ $# -gt 0 ]; do
      case "$1" in
        -d|--diff) MODE="diff"; shift ;;
        -w|--watch) MODE="watch"; shift ;;
        -j|--json) MODE="json"; shift ;;
        -n) INTERVAL="$2"; shift 2 ;;
        -h|--help) usage ;;
        *) echo "Unknown option: $1"; usage ;;
      esac
    done

    case "$MODE" in
      show)  do_show ;;
      diff)  do_diff; exit $? ;;
      json)  do_json ;;
      watch)
        while true; do
          clear
          do_diff || true
          sleep "$INTERVAL"
        done
        ;;
    esac
  '';

  # Maps config mode names to what `maccel get mode | head -1` actually prints.
  modeDisplayMap = {
    linear = "Linear Acceleration";
    natural = "Natural (w/ Gain)";
    synchronous = "Synchronous";
    no-accel = "No Acceleration";
  };

  # ── maccel-logger: periodic health check script ───────────────────────
  # NOTE: deliberately no set -e — this is a diagnostic tool and should never
  # fail the service. The module may not be available during switch/reload.
  maccelLogger = pkgs.writeShellScript "maccel-logger" ''
        set -uo pipefail

        MACCEL="${maccelBin}"
        EXPECTED_MODE="${modeDisplayMap.${expectedParams.mode}}"
        EXPECTED="${mkExpectedStr}"

        LOG_ALL=${if cfg.logging.logAll then "true" else "false"}
        TIMESTAMP=$(date --iso-8601=seconds)

        # Parse expected values
        declare -A EXP
        for pair in $EXPECTED; do
          key="''${pair%%=*}"
          val="''${pair#*=}"
          EXP["$key"]="$val"
        done

        get_mode() {
          $MACCEL get mode 2>/dev/null | head -1 | tr -d '\n'
        }

        get_param() {
          $MACCEL get param "$1" 2>/dev/null || echo "ERR"
        }

        mode=$(get_mode)
        if [ -z "$mode" ]; then
          echo "MACVEL logger[$TIMESTAMP] WARN: cannot read maccel mode — module not loaded?"
          exit 0
        fi

        # Check mode
        if [ "$mode" != "$EXPECTED_MODE" ]; then
          echo "MACVEL logger[$TIMESTAMP] WARN  mode=expected:$EXPECTED_MODE,actual:$mode"
        else
          echo "MACVEL logger[$TIMESTAMP] INFO  mode=$mode"
        fi

        # Check sysfs exists
        if [ ! -d /sys/module/maccel/parameters ]; then
          echo "MACVEL logger[$TIMESTAMP] WARN /sys/module/maccel/parameters not found — module not loaded?"
          exit 0
    fi

        # Dump all sysfs params
        have_diff=false
        for f in /sys/module/maccel/parameters/*; do
          name=$(basename "$f")
          value=$(cat "$f" 2>/dev/null || echo "N/A")
          expected="''${EXP[$name]:-}"

          if [ -n "$expected" ] && [ "$expected" != "null" ]; then
            if [ "$value" != "$expected" ]; then
              echo "MACVEL logger[$TIMESTAMP] WARN  param=$name expected=$expected actual=$value"
              have_diff=true
            elif [ "$LOG_ALL" = "true" ]; then
              echo "MACVEL logger[$TIMESTAMP] INFO  param=$name value=$value"
            fi
          elif [ "$LOG_ALL" = "true" ]; then
            echo "MACVEL logger[$TIMESTAMP] INFO  param=$name value=$value (unconfigured)"
          fi
        done

        if [ "$have_diff" = "false" ]; then
          echo "MACVEL logger[$TIMESTAMP] INFO  all params match expected configuration"
        fi
  '';
in
{
  imports = [
    inputs.maccel.nixosModules.default
  ];

  config = lib.mkIf cfg.enable {
    hardware.maccel = {
      enable = true;
      enableCli = true;

      parameters = {
        mode = cfg.parameters.mode;
        sensMultiplier = cfg.parameters.sensMultiplier;
        yxRatio = cfg.parameters.yxRatio;
        inputDpi = cfg.parameters.inputDpi;
        angleRotation = cfg.parameters.angleRotation;
        acceleration = cfg.parameters.acceleration;
        offset = cfg.parameters.offset;
        outputCap = cfg.parameters.outputCap;
        decayRate = cfg.parameters.decayRate;
        limit = cfg.parameters.limit;
        gamma = cfg.parameters.gamma;
        smooth = cfg.parameters.smooth;
        motivity = cfg.parameters.motivity;
        syncSpeed = cfg.parameters.syncSpeed;
      };
    };

    # Install maccel-watch CLI for interactive diagnostics
    environment.systemPackages = lib.mkIf cfg.logging.watch [ maccelWatch ];

    systemd = {
      services = {
        # Runtime param application — applies the Nix-configured params to the
        # already-loaded kernel module. This is necessary because modprobe
        # options only take effect at module load time (reboot).
        maccel-apply-params = {
          description = "Apply maccel kernel module parameters at runtime";
          after = [ "systemd-modules-load.service" ];
          wantedBy = [ "multi-user.target" ];
          serviceConfig.Type = "oneshot";
          script = lib.concatStringsSep "\n" applyParamsCmds;
        };

        # Periodic health check logger
        maccel-logger = lib.mkIf cfg.logging.enable {
          description = "maccel periodic health check — logs state and detects unexpected changes";
          after = [ "maccel-apply-params.service" ];
          wants = [ "maccel-apply-params.service" ];
          serviceConfig.Type = "oneshot";
          script = "${maccelLogger}";
        };

        # Boot audit: log initial state immediately after params are applied.
        # Logger may return non-zero if module isn't ready (e.g. during switch);
        # that's diagnostic noise, not a service failure.
        maccel-audit = lib.mkIf cfg.logging.enable {
          description = "maccel boot-time state audit";
          after = [ "maccel-apply-params.service" ];
          requires = [ "maccel-apply-params.service" ];
          before = [ "multi-user.target" ];
          wantedBy = [ "multi-user.target" ];
          serviceConfig.Type = "oneshot";
          script = ''
            echo "=== maccel boot audit ==="
            ${maccelLogger} || echo "MACVEL audit: logger exited $?, continuing"
            echo "=== end maccel boot audit ==="
          '';
        };
      };

      timers.maccel-logger = lib.mkIf cfg.logging.enable {
        description = "Periodic maccel state check timer";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "hourly";
          OnBootSec = "1min";
          OnUnitActiveSec = cfg.logging.interval;
          RandomizedDelaySec = "30s";
          Persistent = true;
        };
      };
    };

    # GNOME integration: ensure GNOME's own acceleration is flat so the
    # kernel-level maccel curve is the only active acceleration.
    home-manager.users.${flake.config.me.username}.dconf.settings."org/gnome/desktop/peripherals/mouse" =
      lib.mkIf config.my.desktop.gnome.enable {
        accel-profile = cfg.gnome.accelProfile;
        speed = cfg.gnome.speed;
      };
  };
}
