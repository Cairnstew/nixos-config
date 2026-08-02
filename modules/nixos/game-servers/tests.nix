{ config, lib, ... }:
let
  cfg = config.my.services.game-servers;
  enabledServers = lib.filterAttrs (_: s: s.enable) cfg.servers;

  # Servers with monitoring enabled
  monitoredServers = lib.filterAttrs (_: s: s.monitoring.enable) enabledServers;

  # Check that exporter ports are unique across monitored servers
  exporterPorts = lib.attrValues (lib.mapAttrs (_: s: s.monitoring.exporterPort) monitoredServers);
  uniqueExporterPorts = lib.unique exporterPorts;
in
{
  # ── L0: Nix Assertions ────────────────────────────────────────────────────
  assertions = [
    {
      assertion = !cfg.enable || cfg.user != "root";
      message = "my.services.game-servers.user must not be 'root'. steamcmd refuses to run as root; use a dedicated service user.";
    }
    {
      assertion = !cfg.enable || cfg.servers != { };
      message = "my.services.game-servers is enabled but no servers are defined. Add at least one entry under my.services.game-servers.servers, or disable the module.";
    }
    {
      assertion = lib.all (s: s.appId != "") (lib.attrValues enabledServers);
      message = "Every game server must declare a non-empty appId (Steam App ID of the dedicated server).";
    }
    {
      assertion = lib.all (s: s.startCommand != "") (lib.attrValues enabledServers);
      message = "Every game server must declare a non-empty startCommand (the server binary relative to its stateDir).";
    }
    {
      assertion = !cfg.monitoring.enable || cfg.monitoring.exporter != null;
      message = ''
        my.services.game-servers.monitoring is enabled but no exporter package
        is available. The in-repo `a2s-exporter` package was not found
        (flake.inputs.self.packages.<system>.a2s-exporter). Provide one via
        my.services.game-servers.monitoring.exporter.
      '';
    }
    {
      assertion = builtins.length exporterPorts == builtins.length uniqueExporterPorts;
      message = ''
        Exporter ports must be unique across monitored game servers.
        Conflicting exporterPort values: ${toString exporterPorts}.
        Set a distinct my.services.game-servers.servers.<name>.monitoring.exporterPort per server.
      '';
    }
    {
      assertion = lib.all (s: s.monitoring.queryPort != null) (lib.attrValues monitoredServers);
      message = "Every monitored game server must set monitoring.queryPort (the A2S query port, usually game port + 1).";
    }
    # steam-run (bwrap) is incompatible with strict systemd sandboxing
    {
      assertion = lib.all (s: !(s.extraServiceConfig ? NoNewPrivileges) || !s.extraServiceConfig.NoNewPrivileges) (lib.attrValues enabledServers);
      message = "Do not set NoNewPrivileges in extraServiceConfig for game servers — steam-run (bwrap) requires it to be disabled.";
    }
  ];

  # ── L2: Smoke test ────────────────────────────────────────────────────────
  # Manual: systemctl start game-servers-smoke-test
  systemd.services.game-servers-smoke-test = lib.mkIf cfg.enable {
    description = "Smoke test for my.services.game-servers";
    serviceConfig = {
      Type = "oneshot";
      User = cfg.user;
      Group = cfg.group;
    };
    script = ''
      echo "=== game-servers smoke test ==="
      for name in ${toString (lib.attrNames enabledServers)}; do
        dir=${cfg.dataDir}/$name
        echo "Checking $name (stateDir: $dir)"
        if [ -d "$dir" ]; then
          echo "PASS: $dir exists"
        else
          echo "WARN: $dir does not exist yet (installed on first start)"
        fi
      done
      echo "--- Enabled units ---"
      systemctl list-unit-files 'game-server-*.service' --no-legend 2>/dev/null | grep -q game-server && \
        systemctl list-unit-files 'game-server-*.service' --no-legend || true
      echo "=== smoke test complete ==="
    '';
  };
}
