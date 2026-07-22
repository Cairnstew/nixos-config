{ config, lib, pkgs, ... }:
let
  cfg = config.my.services.proxy;

  enabledUpstreams = lib.filterAttrs (_: u: u.enable) cfg.upstreams;

  # Build a Caddy handle (or handle_path) block for an upstream
  handleBlock = name: upstream:
    let
      directive = if upstream.stripPrefix then "handle_path" else "handle";
      path = "${upstream.path}*";
    in
    ''
      ${directive} ${path} {
        reverse_proxy ${upstream.host}:${toString upstream.port}
        ${upstream.extraConfig}
      }
    '';

  # Dashboard HTML page
  dashboardHtml = pkgs.writeText "dashboard.html" ''
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>${cfg.dashboard.title}</title>
      <style>
        *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
        body {
          font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
          background: #0f0f14;
          color: #e0e0e0;
          min-height: 100vh;
          display: flex;
          flex-direction: column;
          align-items: center;
          padding: 3rem 1rem;
        }
        .container { max-width: 800px; width: 100%; }
        h1 { font-size: 1.75rem; font-weight: 600; margin-bottom: 0.5rem; }
        p.subtitle { color: #888; margin-bottom: 2rem; font-size: 0.95rem; }
        .grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(240px, 1fr)); gap: 1rem; }
        a.card {
          display: block;
          background: #1a1a24;
          border: 1px solid #2a2a38;
          border-radius: 10px;
          padding: 1.25rem;
          text-decoration: none;
          color: inherit;
          transition: border-color 0.2s, transform 0.15s;
        }
        a.card:hover { border-color: #4a4a6a; transform: translateY(-2px); }
        a.card h2 { font-size: 1.1rem; font-weight: 500; margin-bottom: 0.25rem; }
        a.card .path { font-family: "SF Mono", monospace; font-size: 0.8rem; color: #5a8aff; }
        a.card .desc { font-size: 0.8rem; color: #777; margin-top: 0.4rem; }
        .footer { margin-top: 3rem; font-size: 0.75rem; color: #555; }
        .section-title { font-size: 1.1rem; font-weight: 600; margin: 2rem 0 1rem; color: #aaa; text-transform: uppercase; letter-spacing: 0.05em; }
        .metrics-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(260px, 1fr)); gap: 1rem; margin-bottom: 1rem; }
        .metric-card { background: #1a1a24; border: 1px solid #2a2a38; border-radius: 10px; padding: 1rem; }
        .metric-label { font-size: 0.8rem; color: #888; margin-bottom: 0.4rem; text-transform: uppercase; letter-spacing: 0.04em; }
        .metric-bar-bg { height: 8px; background: #2a2a38; border-radius: 4px; overflow: hidden; }
        .metric-bar-fill { height: 100%; border-radius: 4px; transition: width 1s ease; background: linear-gradient(90deg, #5a8aff, #7c6aff); }
        .metric-value { font-size: 1.3rem; font-weight: 700; margin-top: 0.4rem; }
        .metrics-info { display: flex; flex-wrap: wrap; gap: 1.5rem; font-size: 0.85rem; color: #777; margin-top: 1rem; padding: 1rem; background: #1a1a24; border: 1px solid #2a2a38; border-radius: 10px; }
        .metrics-info span { white-space: nowrap; }
      </style>
    </head>
    <body>
      <div class="container">
        <h1>${cfg.dashboard.title}</h1>
        <p class="subtitle">${cfg.dashboard.description}</p>
        <div class="grid">
          ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: u: let displayName = if u.displayName != null then u.displayName else name; in ''
          <a href="${u.path}" class="card">
            <h2>${displayName}</h2>
            <div class="path">${u.path}</div>
          </a>
          '') enabledUpstreams)}
        </div>

        ${lib.optionalString cfg.systemMetrics.enable ''
        <h2 class="section-title">System</h2>
        <div class="metrics-grid">
          <div class="metric-card">
            <div class="metric-label">CPU</div>
            <div class="metric-bar-bg"><div id="cpu-bar" class="metric-bar-fill"></div></div>
            <div class="metric-value" id="cpu-value">--</div>
          </div>
          <div class="metric-card">
            <div class="metric-label">Memory</div>
            <div class="metric-bar-bg"><div id="mem-bar" class="metric-bar-fill" style="background:linear-gradient(90deg,#4ade80,#22c55e)"></div></div>
            <div class="metric-value" id="mem-value">--</div>
          </div>
          <div class="metric-card">
            <div class="metric-label">Disk</div>
            <div class="metric-bar-bg"><div id="disk-bar" class="metric-bar-fill" style="background:linear-gradient(90deg,#f59e0b,#ef4444)"></div></div>
            <div class="metric-value" id="disk-value">--</div>
          </div>
        </div>
        <div class="metrics-info" id="metrics-info">
          <span id="metrics-hostname">--</span>
          <span id="metrics-uptime">--</span>
          <span id="metrics-procs">--</span>
          <span id="metrics-load">--</span>
          <span id="metrics-network">--</span>
          <span id="metrics-latency">--</span>
        </div>
        <script>
        function fmtBytes(b) {
          if (b < 1024) return b + 'B';
          if (b < 1048576) return (b / 1024).toFixed(1) + 'KB';
          if (b < 1073741824) return (b / 1048576).toFixed(1) + 'MB';
          return (b / 1073741824).toFixed(1) + 'GB';
        }
        function fetchMetrics() {
          var t0 = performance.now();
          fetch('/api/metrics/metrics.json').then(function(r) { return r.json(); }).then(function(d) {
            var latency = (performance.now() - t0).toFixed(0);
            document.getElementById('metrics-latency').textContent = latency + 'ms';
            var cpuPct = ((d.cpu.total - d.cpu.idle) / d.cpu.total * 100).toFixed(1);
            document.getElementById('cpu-bar').style.width = Math.min(cpuPct, 100) + '%';
            document.getElementById('cpu-value').textContent = cpuPct + '%';

            var memPct = ((d.memory.totalKb - d.memory.availKb) / d.memory.totalKb * 100).toFixed(1);
            document.getElementById('mem-bar').style.width = Math.min(memPct, 100) + '%';
            document.getElementById('mem-value').textContent = memPct + '%';

            var diskPct = (d.disk.used / d.disk.total * 100).toFixed(1);
            document.getElementById('disk-bar').style.width = Math.min(diskPct, 100) + '%';
            document.getElementById('disk-value').textContent = diskPct + '%';

            document.getElementById('metrics-hostname').textContent = d.hostname;
            var up = d.uptime;
            var upDays = Math.floor(up / 86400);
            var upHours = Math.floor((up % 86400) / 3600);
            var upMins = Math.floor((up % 3600) / 60);
            document.getElementById('metrics-uptime').textContent = 'Up ' + upDays + 'd ' + upHours + 'h ' + upMins + 'm';
            document.getElementById('metrics-procs').textContent = d.procs + ' procs';
            document.getElementById('metrics-load').textContent = 'Load: ' + d.load['1min'].toFixed(2);
            document.getElementById('metrics-network').textContent = 'RX: ' + fmtBytes(d.network.rxBytes) + ' | TX: ' + fmtBytes(d.network.txBytes);
          }).catch(function() {});
        }
        fetchMetrics();
        setInterval(fetchMetrics, 10000);
        </script>
        ''}

        <p class="footer"><script>document.write(window.location.host)</script></p>
      </div>
    </body>
    </html>
  '';

  dashboardDir = pkgs.runCommand "dashboard" { } ''
    mkdir -p $out
    cp ${dashboardHtml} $out/index.html
  '';

  # Use :port as the site address (catch-all for any Host header — required
  # because Tailscale serve preserves the original Host when forwarding).
  # The bind directive restricts which interfaces Caddy actually listens on.
  # http:// prefix disables automatic TLS — Tailscale handles HTTPS at the edge.

  # Build bind directive from listenAddresses
  bindList = lib.concatStringsSep " " cfg.listenAddresses;

  # Generate Caddyfile
  caddyfile = pkgs.writeText "Caddyfile" ''
    http://:${toString cfg.port} {
      bind ${bindList}
      ${lib.optionalString cfg.systemMetrics.enable ''
      handle_path /api/metrics/* {
        root * /run/metrics
        file_server
      }
      ''}

      ${lib.optionalString cfg.dashboard.enable ''
      handle /index.html {
        root * ${dashboardDir}
        file_server
      }
      handle / {
        root * ${dashboardDir}
        file_server
      }
      ''}

      ${lib.concatStringsSep "\n" (lib.mapAttrsToList handleBlock enabledUpstreams)}

      ${lib.concatStringsSep "\n" (lib.concatMap (u: u.extraLocations) (builtins.attrValues enabledUpstreams))}

      handle {
        respond "Not Found" 404
      }

      ${cfg.extraConfig}
    }
  '';

  # Tailscale serve URL (uses the first listen address)
  tailscaleUrl = "http://${builtins.elemAt cfg.listenAddresses 0}:${toString cfg.port}";

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
        network: { rxBytes: $rxBytes, txBytes: $txBytes }
      }' > /run/metrics/metrics.json
  '';
in
{
  config = lib.mkIf cfg.enable {
    services.caddy = {
      enable = true;
      configFile = caddyfile;
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
        ExecStart = "${pkgs.tailscale}/bin/tailscale serve --bg --https ${toString cfg.tailscaleServe.httpsPort} ${tailscaleUrl}";
        ExecStop = "${pkgs.tailscale}/bin/tailscale serve --https ${toString cfg.tailscaleServe.httpsPort} off";
      };
    };
  };
}
