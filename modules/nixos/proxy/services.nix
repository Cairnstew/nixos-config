# Systemd service definitions (F9c split): caddy service EnvironmentFile,
# system metrics collection, and tailscale serve. Extracted verbatim from
# the former config.nix monolith. Plain function file — imported from
# config.nix with the shared values, NOT a module.
{ cfg, tailscaleUrl, tailscaleExpectedMtuJson, lib, pkgs, ... }:
let
  # System metrics collection script
  metricsScript = pkgs.writeShellScript "collect-metrics" ''
    set -euo pipefail
    mkdir -p /run/metrics

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

    ${lib.getExe pkgs.jq} -n \
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
  '';
in
{
  systemd.services.caddy.serviceConfig.EnvironmentFile = cfg.extraCaddyEnvironmentFiles;

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
      ProtectHome = true;
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
