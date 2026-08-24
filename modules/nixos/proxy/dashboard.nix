# Dashboard static page (F9c split): the embedded HTML/CSS/JS served at the
# proxy root. Extracted verbatim from the former config.nix monolith.
# Plain function file (same pattern as modules/home/opencode/providers.nix) —
# imported from config.nix, NOT a module, so it stays out of default.nix imports.
{ cfg, enabledUpstreams, lib, pkgs, ... }:
let
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
        .oc-instance { background: #1a1a24; border: 1px solid #2a2a38; border-radius: 10px; padding: 1rem; display: flex; flex-direction: column; gap: 0.6rem; }
        .oc-instance .oc-sessions { display: flex; flex-direction: column; gap: 0.25rem; }
        .oc-session { font-size: 0.8rem; color: #9db4ff; text-decoration: none; padding: 0.2rem 0.4rem; border-radius: 6px; background: #14141d; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
        .oc-session:hover { background: #1e1e2e; color: #c3d0ff; }
        .oc-empty { font-size: 0.8rem; color: #555; }
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
          <span id="metrics-tailscale">--</span>
          <span id="metrics-ssh">--</span>
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

            var ts = d.tailscale || {};
            var tsUp = !!ts.up;
            var tsMtu = ts.mtu != null ? ts.mtu : 'n/a';
            var tsExpected = ts.expectedMtu != null ? ts.expectedMtu : null;
            var tsOk = tsExpected == null || ts.mtu === tsExpected;
            var tsEl = document.getElementById('metrics-tailscale');
            var tsInfo = 'TS MTU: ' + tsMtu + ' (' + (tsUp ? 'up' : 'down');
            if (tsExpected != null) { tsInfo += (tsOk ? ' ok' : ' !=' + tsExpected); }
            tsInfo += ')';
            tsEl.textContent = tsInfo;
            tsEl.style.color = tsUp && tsOk ? '#4ade80' : '#ef4444';

            var sshUp = d.ssh && d.ssh.listening;
            var sshEl = document.getElementById('metrics-ssh');
            sshEl.textContent = 'SSH: ' + (sshUp ? 'up' : 'down');
            sshEl.style.color = sshUp ? '#4ade80' : '#ef4444';
          }).catch(function() {});
        }
        fetchMetrics();
        setInterval(fetchMetrics, 10000);
        </script>
        ''}

        ${lib.optionalString (cfg.systemMetrics.enable && cfg.systemMetrics.opencodeGo.usageJsonFile != null) ''
        <h2 class="section-title">OpenCode Go Usage</h2>
        <div class="metrics-grid">
          ${lib.concatStringsSep "\n" (map (w: ''
          <div class="metric-card">
            <div class="metric-label">${w}</div>
            <div class="metric-bar-bg"><div id="oc-${w}-bar" class="metric-bar-fill"></div></div>
            <div class="metric-value" id="oc-${w}-value">--</div>
            <div style="font-size:0.75rem;color:#777;margin-top:0.3rem" id="oc-${w}-reset"></div>
          </div>
          '') [ "rolling" "weekly" "monthly" ])}
        </div>
        <script>
        function ocUsageUpdate(d) {
          var oc = d.opencodeGo;
          if (!oc) return;
          ['rolling', 'weekly', 'monthly'].forEach(function (w) {
            var win = oc[w];
            if (!win) return;
            var bar = document.getElementById('oc-' + w + '-bar');
            var val = document.getElementById('oc-' + w + '-value');
            var reset = document.getElementById('oc-' + w + '-reset');
            if (!bar || !val) return;
            bar.style.width = Math.min(win.percent, 100) + '%';
            bar.style.background = win.percent >= 90 ? '#ef4444'
              : win.percent >= 70 ? '#f59e0b' : 'linear-gradient(90deg, #5a8aff, #7c6aff)';
            val.textContent = win.percent + '%';
            if (reset && win.resetsAt) {
              var mins = Math.max(0, Math.round((new Date(win.resetsAt) - Date.now()) / 60000));
              var hrs = Math.floor(mins / 60);
              reset.textContent = 'resets in ' + (hrs > 0 ? hrs + 'h ' : String()) + (mins % 60) + 'm';
            }
          });
        }
        // own poll — the system-metrics setInterval captured the original
        // fetchMetrics reference, so wrapping/reassigning it here would never run.
        function ocUsageFetch() {
          fetch('/api/metrics/metrics.json').then(function (r) { return r.json(); }).then(ocUsageUpdate).catch(function () {});
        }
        ocUsageFetch();
        setInterval(ocUsageFetch, 10000);
        </script>
        ''}

        ${lib.optionalString (cfg.dashboard.opencode != []) ''
        <h2 class="section-title">OpenCode</h2>
        <div class="grid">
          ${lib.concatStringsSep "\n" (map (i: ''
          <div class="oc-instance" data-api="${i.apiPath}" data-href="${i.href}"${lib.optionalString (i.servePort != null) " data-serve-port=\"${toString i.servePort}\""} data-directory="${i.directory}">
            <a href="${i.href}" class="card">
              <h2>opencode · ${i.label}</h2>
              <div class="path">${i.directory}</div>
            </a>
            <div class="oc-sessions"><span class="oc-empty">Loading sessions…</span></div>
          </div>
          '') cfg.dashboard.opencode)}
        </div>
        <script>
        // Live opencode session list per instance. Sessions are fetched through a
        // same-origin Caddy handle (apiPath) so it works over both http/https;
        // each session deep-links into the web UI via the legacy
        // /<base64(directory)>/session/<id> route.
        //
        // UI links: when the instance is exposed on the tailnet (servePort set)
        // and the dashboard is viewed via the tailnet hostname, link to
        // https://<current-host>:<servePort>/; otherwise fall back to the direct
        // href (http://localhost:<backend port>/).
        function ocUiLink(inst) {
          var host = window.location.hostname;
          var local = host === 'localhost' || host === '127.0.0.1' || host === '::1';
          if (!local && inst.dataset.servePort) {
            return 'https://' + host + ':' + inst.dataset.servePort + '/';
          }
          return inst.dataset.href;
        }
        document.querySelectorAll('.oc-instance').forEach(function (inst) {
          var api = inst.dataset.api;
          var ui = ocUiLink(inst);
          var dirB64 = btoa(inst.dataset.directory);
          var box = inst.querySelector('.oc-sessions');
          var card = inst.querySelector('a.card');
          card.href = ui;
          fetch(api + '/session').then(function (r) {
            if (!r.ok) throw new Error('status ' + r.status);
            return r.json();
          }).then(function (d) {
            var list = Array.isArray(d) ? d : ((d && (d.sessions || d.data)) || []);
            if (!list.length) {
              box.innerHTML = '<span class="oc-empty">No sessions</span>';
              return;
            }
            box.innerHTML = list.slice(0, 10).map(function (s) {
              var title = s.title || s.id || '(untitled)';
              return '<a class="oc-session" href="' + ui + '/' + dirB64 + '/session/' + s.id + '">' + title + '</a>';
            }).join("");
          }).catch(function (e) {
            box.innerHTML = '<span class="oc-empty">Sessions unavailable (' + e.message + ')</span>';
          });
        });
        </script>
        ''}

        ${lib.optionalString cfg.dashboard.minecraft.enable ''
        <h2 class="section-title">Minecraft</h2>
        <div class="metrics-grid" id="minecraft-servers">
          <div class="oc-empty">Loading…</div>
        </div>
        <script>
        // Minecraft server management: live status + start/stop/restart toggles.
        // Backed by the minecraft-server module's management API (proxied at
        // dashboard.minecraft.apiPath), which reports per-server systemd state,
        // players, and uptime, and accepts start/stop/restart POSTs.
        var mcApi = '${cfg.dashboard.minecraft.apiPath}';
        function mcCard(s) {
          var ok = s.active;
          var state = ok ? 'online' : 'offline';
          var pill = '<span style="display:inline-block;width:10px;height:10px;border-radius:50%;background:' + (ok ? '#4ade80' : '#ef4444') + ';margin-right:6px"></span>';
          var btn = function (a, label) {
            return '<button data-mc-action="' + a + '" data-mc-name="' + s.name + '" style="padding:4px 12px;margin-right:6px;border-radius:6px;border:1px solid #2a2a38;background:#14141d;color:#e0e0e0;cursor:pointer">' + label + '</button>';
          };
          return '<div class="metric-card">' +
            '<div class="metric-label">' + pill + s.name + ' · ' + state + '</div>' +
            '<div class="metric-value">' + (s.players != null ? s.players + ' players' : '—') + '</div>' +
            '<div class="metrics-info">' + (s.uptime ? 'up ' + s.uptime : "") + '</div>' +
            '<div style="margin-top:10px">' +
              btn('start', 'Start') + btn('stop', 'Stop') + btn('restart', 'Restart') +
              (s.console ? '<a href="' + s.console + '" style="padding:4px 12px;border-radius:6px;border:1px solid #2a2a38;background:#14141d;color:#5a8aff;text-decoration:none">Console</a>' : "") +
            '</div></div>';
        }
        function mcRefresh() {
          fetch(mcApi + '/status').then(function (r) { return r.json(); }).then(function (d) {
            var servers = Array.isArray(d) ? d : (d && d.servers ? d.servers : []);
            var box = document.getElementById('minecraft-servers');
            if (!servers.length) { box.innerHTML = '<div class="oc-empty">No servers configured</div>'; return; }
            box.innerHTML = servers.map(mcCard).join("");
          }).catch(function (e) {
            document.getElementById('minecraft-servers').innerHTML = '<div class="oc-empty">Unavailable (' + e.message + ')</div>';
          });
        }
        document.addEventListener('click', function (ev) {
          var el = ev.target.closest('[data-mc-action]');
          if (!el) return;
          var name = el.dataset.mcName, action = el.dataset.mcAction;
          fetch(mcApi + '/' + name + '/' + action, { method: 'POST' }).then(function (r) {
            setTimeout(mcRefresh, 1500);
          }).catch(function () {});
        });
        mcRefresh();
        setInterval(mcRefresh, 10000);
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
in
{
  # Buildable dashboard directory (index.html) for the Caddyfile file_server.
  inherit dashboardDir;
}
