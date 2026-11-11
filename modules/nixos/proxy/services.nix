# Systemd service definitions (F9c split): caddy service EnvironmentFile,
# system metrics collection, and tailscale serve. Extracted verbatim from
# the former config.nix monolith. Plain function file — imported from
# config.nix with the shared values, NOT a module.
{ cfg, tailscaleUrl, tailscaleExpectedMtuJson, lib, pkgs, config, ... }:
let
  jqBin = lib.getExe pkgs.jq;

  authEnabled = cfg.dashboard.auth.enable;
  authSecretExists = lib.hasAttr cfg.dashboard.auth.passwordSecret config.age.secrets;
  # /dev/null is only a placeholder: the unit is not created when the secret
  # is absent, and tests.nix turns that state into a build-time assertion.
  authSecretPath =
    if authSecretExists
    then config.age.secrets.${cfg.dashboard.auth.passwordSecret}.path
    else "/dev/null";

  # System metrics collection script
  metricsScript = pkgs.writeShellScript "collect-metrics" ''
    set -euo pipefail
    mkdir -p /run/metrics

    # Numeric-or-null helpers: nvidia-smi prints [N/A] for unsupported
    # fields and sysfs files may be absent, so every optional value is
    # validated before it reaches --argjson.
    num_or_null() {
      case "$1" in
        *[!0-9.eE+-]*|"") printf 'null' ;;
        *) printf '%s' "$1" ;;
      esac
    }
    is_uint() {
      case "$1" in
        *[!0-9]*|"") return 1 ;;
        *) return 0 ;;
      esac
    }

    # CPU cumulative counters
    read cpu user nice system idle iowait irq softirq steal rest < /proc/stat
    total=$((user + nice + system + idle + iowait + irq + softirq + steal))

    # Memory
    memtotal=$(awk '/^MemTotal:/{print $2}' /proc/meminfo)
    memavail=$(awk '/^MemAvailable:/{print $2}' /proc/meminfo)

    # Uptime
    uptime=$(awk '{print $1}' /proc/uptime)

    # Load
    read load1 load5 load15 rest < /proc/loadavg

    # Disk
    disk_total=$(df -B1 / | awk 'NR==2{print $2}')
    disk_used=$(df -B1 / | awk 'NR==2{print $3}')

    # Processes
    procs=$(ps --no-headers -e 2>/dev/null | wc -l || echo 0)

    # Host info
    read -r hostname < /proc/sys/kernel/hostname
    kernel=$(uname -r)

    # Network (cumulative)
    rx_bytes=0; tx_bytes=0
    for f in /sys/class/net/*/statistics/rx_bytes; do
      [ -r "$f" ] && rx_bytes=$((rx_bytes + $(cat "$f")))
    done
    for f in /sys/class/net/*/statistics/tx_bytes; do
      [ -r "$f" ] && tx_bytes=$((tx_bytes + $(cat "$f")))
    done

    # Tailscale tunnel — live MTU vs expected (drift = wedged data plane)
    ts_mtu=null
    ts_up=false
    if [ -r /sys/class/net/tailscale0/mtu ]; then
      ts_mtu=$(cat /sys/class/net/tailscale0/mtu)
      ts_up=true
    fi

    # SSH daemon
    ssh_up=false
    if pgrep -x sshd >/dev/null 2>&1; then
      ssh_up=true
    fi

    # ── GPU telemetry ─────────────────────────────────────────────────────
    # NVIDIA: nvidia-smi (utilization, VRAM, temp, power). Guarded by an
    # existence check and wrapped in timeout so a missing or wedged driver
    # cannot stall the collector.
    # AMD/Intel: DRM sysfs. amdgpu exposes gpu_busy_percent and VRAM totals;
    # i915/xe expose neither, so utilization is reported as null there.
    gpu_jsonl=/run/metrics/.gpus.jsonl
    : > "$gpu_jsonl"

    nvidia_smi=/run/current-system/sw/bin/nvidia-smi
    if [ -x "$nvidia_smi" ]; then
      nvidia_out=$(timeout 5 "$nvidia_smi" \
        --query-gpu=index,name,utilization.gpu,memory.used,memory.total,temperature.gpu,power.draw,power.limit \
        --format=csv,noheader,nounits 2>/dev/null || true)
      while IFS= read -r line; do
        [ -n "$line" ] || continue
        IFS=',' read -r nv_idx nv_name nv_util nv_memused nv_memtotal nv_temp nv_power nv_plimit _rest <<< "$line"
        nv_name=$(printf '%s' "$nv_name" | awk '{$1=$1};1')
        "${jqBin}" -n \
          --arg name "$nv_name" \
          --arg vendor "NVIDIA" \
          --arg driver "nvidia" \
          --argjson utilization "$(num_or_null "$(printf '%s' "$nv_util" | tr -d ' ')")" \
          --argjson memoryUsedMiB "$(num_or_null "$(printf '%s' "$nv_memused" | tr -d ' ')")" \
          --argjson memoryTotalMiB "$(num_or_null "$(printf '%s' "$nv_memtotal" | tr -d ' ')")" \
          --argjson temperatureC "$(num_or_null "$(printf '%s' "$nv_temp" | tr -d ' ')")" \
          --argjson powerW "$(num_or_null "$(printf '%s' "$nv_power" | tr -d ' ')")" \
          --argjson powerLimitW "$(num_or_null "$(printf '%s' "$nv_plimit" | tr -d ' ')")" \
          '{ name: $name, vendor: $vendor, driver: $driver, utilization: $utilization,
             memoryUsedMiB: $memoryUsedMiB, memoryTotalMiB: $memoryTotalMiB,
             temperatureC: $temperatureC, powerW: $powerW, powerLimitW: $powerLimitW }' \
          >> "$gpu_jsonl"
      done <<< "$nvidia_out"
    fi

    for card in /sys/class/drm/card[0-9]*; do
      [ -e "$card/device/driver" ] || continue
      drv=$(basename "$(readlink -f "$card/device/driver")")
      case "$drv" in
        amdgpu) gpu_name="AMD Radeon"; gpu_vendor="AMD" ;;
        i915|xe) gpu_name="Intel Graphics"; gpu_vendor="Intel" ;;
        *) continue ;;
      esac

      busy_raw=$(cat "$card/device/gpu_busy_percent" 2>/dev/null || true)
      vtotal_raw=$(cat "$card/device/mem_info_vram_total" 2>/dev/null || true)
      vused_raw=$(cat "$card/device/mem_info_vram_used" 2>/dev/null || true)
      temp_raw=$(cat "$card/device/hwmon/"hwmon*/temp1_input 2>/dev/null | head -n1 || true)
      power_raw=$(cat "$card/device/hwmon/"hwmon*/power1_average 2>/dev/null | head -n1 || true)
      if [ -z "$power_raw" ]; then
        power_raw=$(cat "$card/device/hwmon/"hwmon*/power1_input 2>/dev/null | head -n1 || true)
      fi

      if is_uint "$busy_raw"; then busy="$busy_raw"; else busy=""; fi
      vtotal_mib=""; vused_mib=""
      if is_uint "$vtotal_raw"; then vtotal_mib=$(( vtotal_raw / 1048576 )); fi
      if is_uint "$vused_raw"; then vused_mib=$(( vused_raw / 1048576 )); fi
      temp_c=""
      if is_uint "$temp_raw"; then temp_c=$(( temp_raw / 1000 )); fi
      power_w=""
      if is_uint "$power_raw"; then power_w=$(( power_raw / 1000000 )); fi

      "${jqBin}" -n \
        --arg name "$gpu_name" \
        --arg vendor "$gpu_vendor" \
        --arg driver "$drv" \
        --argjson utilization "$(num_or_null "$busy")" \
        --argjson memoryUsedMiB "$(num_or_null "$vused_mib")" \
        --argjson memoryTotalMiB "$(num_or_null "$vtotal_mib")" \
        --argjson temperatureC "$(num_or_null "$temp_c")" \
        --argjson powerW "$(num_or_null "$power_w")" \
        '{ name: $name, vendor: $vendor, driver: $driver, utilization: $utilization,
           memoryUsedMiB: $memoryUsedMiB, memoryTotalMiB: $memoryTotalMiB,
           temperatureC: $temperatureC, powerW: $powerW }' \
        >> "$gpu_jsonl"
    done

    # ── Temperatures (hwmon) ──────────────────────────────────────────────
    # Per-chip maximum across its temp*_input sensors. The dashboard uses
    # the k10temp/coretemp entry for CPU temperature and nvme for the SSD.
    temp_jsonl=/run/metrics/.temps.jsonl
    : > "$temp_jsonl"
    for hw in /sys/class/hwmon/hwmon*; do
      [ -r "$hw/name" ] || continue
      hw_name=$(cat "$hw/name")
      hw_max=""
      for tf in "$hw"/temp*_input; do
        [ -r "$tf" ] || continue
        tv=$(cat "$tf" 2>/dev/null || true)
        is_uint "$tv" || continue
        tc=$(( tv / 1000 ))
        if [ -z "$hw_max" ] || [ "$tc" -gt "$hw_max" ]; then hw_max="$tc"; fi
      done
      [ -n "$hw_max" ] || continue
      "${jqBin}" -n --arg name "$hw_name" --argjson tempC "$hw_max" \
        '{ name: $name, tempC: $tempC }' >> "$temp_jsonl"
    done

    ${jqBin} -n \
      --argjson ts "$(date +%s)" \
      --arg hostname "$hostname" \
      --arg kernel "$kernel" \
      --argjson uptime "$uptime" \
      --argjson cpuUser "$user" \
      --argjson cpuNice "$nice" \
      --argjson cpuSystem "$system" \
      --argjson cpuIdle "$idle" \
      --argjson cpuTotal "$total" \
      --argjson memTotalKb "$memtotal" \
      --argjson memAvailKb "$memavail" \
      --argjson diskTotal "$disk_total" \
      --argjson diskUsed "$disk_used" \
      --argjson load1 "$load1" \
      --argjson load5 "$load5" \
      --argjson load15 "$load15" \
      --argjson procs "$procs" \
      --argjson rxBytes "$rx_bytes" \
      --argjson txBytes "$tx_bytes" \
      --argjson tailscaleMtu "$ts_mtu" \
      --argjson tailscaleUp "$ts_up" \
      --argjson sshUp "$ssh_up" \
      '{
        timestamp: $ts,
        hostname: $hostname,
        kernel: $kernel,
        uptime: $uptime,
        cpu: { user: $cpuUser, nice: $cpuNice, system: $cpuSystem, idle: $cpuIdle, total: $cpuTotal },
        memory: { totalKb: $memTotalKb, availKb: $memAvailKb },
        disk: { total: $diskTotal, used: $diskUsed },
        load: { "1min": $load1, "5min": $load5, "15min": $load15 },
        procs: $procs,
        network: { rxBytes: $rxBytes, txBytes: $txBytes },
        tailscale: { mtu: $tailscaleMtu, up: $tailscaleUp, expectedMtu: ${tailscaleExpectedMtuJson} },
        ssh: { listening: $sshUp }
      }' > /run/metrics/metrics.json

    # Fold GPU + temperature telemetry into the payload. --slurpfile reads
    # the JSONL side files into arrays; an empty file yields [].
    "${jqBin}" --slurpfile gpus "$gpu_jsonl" --slurpfile temps "$temp_jsonl" \
      '. + { gpus: $gpus, temps: $temps }' \
      /run/metrics/metrics.json > /run/metrics/metrics.json.tmp \
      && mv /run/metrics/metrics.json.tmp /run/metrics/metrics.json
    rm -f "$gpu_jsonl" "$temp_jsonl"
    ${lib.optionalString (cfg.systemMetrics.opencodeGo.usageJsonFile != null) ''
    # Merge the OpenCode Go usage snapshot (written by the user-level
    # opencode-go-usage refresher) into the dashboard payload. Best-effort:
    # a stale/missing snapshot must not take down system metrics.
    if ${jqBin} -e . ${cfg.systemMetrics.opencodeGo.usageJsonFile} >/dev/null 2>&1; then
      ${jqBin} -s '.[0] + { opencodeGo: .[1].usage }' \
        /run/metrics/metrics.json \
        ${cfg.systemMetrics.opencodeGo.usageJsonFile} \
        > /run/metrics/metrics.json.tmp \
        && mv /run/metrics/metrics.json.tmp /run/metrics/metrics.json
    fi
    ''}
  '';
in
{
  # Caddy loads the dashboard credentials from a root-only env file generated
  # at boot from the agenix secret. The plaintext password stays on disk in
  # /run/agenix; only the bcrypt hash reaches Caddy.
  systemd.services.caddy = {
    serviceConfig.EnvironmentFile = cfg.extraCaddyEnvironmentFiles
      ++ lib.optional authEnabled "/run/caddy-auth/basic-auth.env";
  } // lib.optionalAttrs authEnabled {
    after = [ "dashboard-auth-env.service" ];
    wants = [ "dashboard-auth-env.service" ];
  };

  systemd.services.dashboard-auth-env = lib.mkIf (authEnabled && authSecretExists) {
    description = "Hash the dashboard basic-auth password for Caddy";
    before = [ "caddy.service" ];
    requiredBy = [ "caddy.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      RuntimeDirectory = "caddy-auth";
      RuntimeDirectoryMode = "0700";
    };
    script = ''
      set -euo pipefail
      umask 077
      hash="$(${lib.getExe config.services.caddy.package} hash-password --plaintext "$(cat ${authSecretPath})")"
      printf 'DASHBOARD_AUTH_USER=%s\nDASHBOARD_AUTH_HASH=%s\n' \
        ${lib.escapeShellArg cfg.dashboard.auth.username} "$hash" \
        > /run/caddy-auth/basic-auth.env
    '';
  };

  systemd.services.metrics-collect = lib.mkIf cfg.systemMetrics.enable {
    description = "Collect system metrics for dashboard";
    after = [ "local-fs.target" ];
    path = with pkgs; [ coreutils gawk jq procps ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${metricsScript}";
      Nice = 19;
      IOSchedulingClass = "idle";
      PrivateTmp = true;
      ProtectSystem = "strict";
      # read-only (instead of true) so the collector can read the OpenCode Go
      # usage snapshot from the user's home directory when configured.
      ProtectHome =
        if cfg.systemMetrics.opencodeGo.usageJsonFile != null
        then "read-only"
        else true;
      ReadWritePaths = [ "/run/metrics" ];
    };
  };

  systemd.timers.metrics-collect = lib.mkIf cfg.systemMetrics.enable {
    description = "Periodic system metrics collection";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "30s";
      OnUnitActiveSec = "${toString cfg.systemMetrics.refreshInterval}s";
      Unit = "metrics-collect.service";
    };
  };

  systemd.tmpfiles.rules = lib.mkIf cfg.systemMetrics.enable [
    "d /run/metrics 0755 root root -"
  ];

  systemd.services.tailscale-serve = lib.mkIf cfg.tailscaleServe.enable {
    description = "Tailscale Serve — route :${toString cfg.tailscaleServe.httpsPort} to Caddy reverse proxy";
    after = [ "tailscaled.service" "caddy.service" ];
    wants = [ "caddy.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      Restart = "on-failure";
      RestartSec = "5s";
      ExecStartPre = "${pkgs.bash}/bin/bash -c 'while ! ${pkgs.tailscale}/bin/tailscale status 2>/dev/null | grep -q .; do sleep 1; done'";
      ExecStart = "${pkgs.tailscale}/bin/tailscale serve --bg --https ${toString cfg.tailscaleServe.httpsPort} ${tailscaleUrl}";
      ExecStop = "${pkgs.tailscale}/bin/tailscale serve --https ${toString cfg.tailscaleServe.httpsPort} off";
    };
  };
}
