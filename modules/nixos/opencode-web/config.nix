{ config, lib, pkgs, ... }:

let
  inherit (lib)
    mkIf
    mkMerge
    optionalString
    concatStringsSep
    map
    filter
    any
    ;

  cfg = config.my.services.opencodeWeb;
  syncRepos = config.my.services.gitRepoSync.repos or { };

  # Wrap opencode so libstdc++.so.6 is on the library path for the native
  # file-watcher binding (mirrors modules/home/opencode/config.nix).
  opencodeWrapped = pkgs.symlinkJoin {
    name = "opencode-wrapped";
    paths = [ cfg.package ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram "$out/bin/opencode" \
        --prefix LD_LIBRARY_PATH : "${pkgs.lib.makeLibraryPath [ pkgs.stdenv.cc.cc.lib ]}"
    '';
  };

  # Deterministic index assignment: sorted repos get 0, 1, 2, …
  sortedRepos = builtins.sort (a: b: a < b) cfg.repos;
  idxFor = name:
    builtins.head (builtins.filter (i: i != null) (lib.imap0
      (i: r: if r == name then i else null)
      sortedRepos));

  mkInstance = name:
    let
      repo = syncRepos.${name} or null;
      path = if repo == null then "/missing/${name}" else repo.path;
      over = cfg.instances.${name} or { };
      port = over.port or (cfg.basePort + idxFor name);
      servePort = over.servePort or (cfg.tailnetServe.basePort + idxFor name);
      hostname = over.hostname or cfg.hostname;
      openFirewall = over.openFirewall or cfg.openFirewall;
    in
    {
      inherit name path port servePort hostname openFirewall;
      extraArgs = over.extraArgs or [ ];
    };

  instances = map mkInstance sortedRepos;

  # Runtime wrapper: optional password injection + first-boot wait for the
  # gitRepoSync clone, then exec opencode web in the repo's working directory.
  mkScript = inst: pkgs.writeShellScript "opencode-web-${inst.name}" ''
    set -euo pipefail

    ${optionalString (cfg.passwordFile != null) ''
      if [[ -r ${cfg.passwordFile} ]]; then
        export OPENCODE_SERVER_PASSWORD="$(cat ${cfg.passwordFile} | tr -d '[:space:]')"
      else
        echo "opencode-web: warning: password file not readable: ${cfg.passwordFile}" >&2
      fi
    ''}

    # gitRepoSync clones the repo on first boot; wait for the checkout to exist.
    for _ in $(seq 1 90); do
      [[ -d "${inst.path}/.git" ]] && break
      sleep 2
    done

    exec ${opencodeWrapped}/bin/opencode web \
      --hostname ${inst.hostname} \
      --port ${toString inst.port} \
      ${concatStringsSep " " inst.extraArgs}
  '';

  # Session gate: refuse to start while a terminal opencode session holds the
  # lock (its PID). A stale lock (dead PID) is cleared so the service recovers
  # after a crash.
  sessionGateScript = pkgs.writeShellScript "opencode-web-session-gate" ''
    set -euo pipefail
    lock=${cfg.sessionGate.lockPath}
    if [[ -f "$lock" ]]; then
      pid=$(cat "$lock")
      if kill -0 "$pid" 2>/dev/null; then
        echo "opencode-web: refusing to start — terminal opencode session (pid $pid) is running." >&2
        echo "  Close the terminal session, or remove $lock to force start." >&2
        exit 1
      fi
      echo "opencode-web: removing stale terminal lock (pid $pid)" >&2
      rm -f "$lock"
    fi
    exit 0
  '';

  mkService = inst: {
    "opencode-web-${inst.name}" = {
      description = "opencode web: ${inst.name} (${inst.path})";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        WorkingDirectory = inst.path;
        Restart = "on-failure";
        RestartSec = "5s";
        # The `open` npm call the web command makes respects $BROWSER; point it
        # at a no-op so headless start doesn't try to spawn a browser.
        Environment = [
          "HOME=${config.users.users.${cfg.user}.home or "/home/${cfg.user}"}"
          "BROWSER=${pkgs.coreutils}/bin/true"
          "GIT_TERMINAL_PROMPT=0"
        ];
        ExecStart = mkScript inst;
      }
      # Teammates spawned by the ensemble run in this cgroup; cap it so a
      # runaway browser team can't OOM the host (see GOTCHAS.md).
      // (lib.optionalAttrs (cfg.memoryHigh != null) { MemoryHigh = cfg.memoryHigh; })
      // (lib.optionalAttrs (cfg.memoryMax != null) { MemoryMax = cfg.memoryMax; })
      # Session gate: refuse to start while a terminal opencode session holds
      # the lock (its PID). A stale lock (dead PID) is cleared so the service
      # recovers after a crash.
      // (lib.optionalAttrs cfg.sessionGate.enable { ExecStartPre = sessionGateScript; });
    };
  };

  # Tailscale serve oneshot: exposes the instance's local port on the tailnet
  # as https://<host>.ts.net:<servePort>/. Mirrors the proxy module's
  # tailscale-serve service (--bg persists the rule in tailscaled).
  mkServeService = inst: {
    "opencode-web-serve-${inst.name}" = {
      description = "tailscale serve: opencode ${inst.name} on :${toString inst.servePort}";
      after = [ "tailscaled.service" "opencode-web-${inst.name}.service" ];
      wants = [ "tailscaled.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        Restart = "on-failure";
        RestartSec = "5s";
        ExecStartPre = "${pkgs.bash}/bin/bash -c 'while ! ${pkgs.tailscale}/bin/tailscale status 2>/dev/null | grep -q .; do sleep 1; done'";
        ExecStart = "${pkgs.tailscale}/bin/tailscale serve --bg --https ${toString inst.servePort} http://127.0.0.1:${toString inst.port}";
        ExecStop = "${pkgs.tailscale}/bin/tailscale serve --https ${toString inst.servePort} off";
      };
    };
  };

  # Data for the proxy dashboard's OpenCode section (rendered by the proxy
  # module). Session deep-links are built at runtime by dashboard JS from
  # `href + "/" + btoa(directory) + "/session/" + id`.
  dashboardInstances = map
    (inst: {
      inherit (inst) name port;
      label = inst.name;
      host = "127.0.0.1";
      href = "${cfg.dashboard.baseUrl}:${toString inst.port}/";
      servePort = if cfg.tailnetServe.enable then inst.servePort else null;
      apiPath = "/opencode-api/${inst.name}";
      # Caddy injects the basic-auth header for the API handle so the dashboard
      # session fetch works without the browser sending credentials.
      apiAuthEnv = if cfg.passwordFile != null then "OPENCODE_WEB_BASIC_AUTH" else null;
      directory = inst.path;
    })
    instances;

  # Generate /run/opencode-web/caddy.env with the basic-auth header value so
  # Caddy can inject `Authorization: Basic …` into the dashboard API handles
  # without baking the secret into the Caddyfile (which lives in the Nix store).
  mkAuthEnvService = {
    "opencode-web-auth-env" = {
      description = "opencode web: generate Caddy basic-auth env";
      before = [ "caddy.service" ];
      wantedBy = [ "multi-user.target" ];
      path = with pkgs; [ coreutils bash ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        set -euo pipefail
        mkdir -p /run/opencode-web
        umask 077
        {
          printf 'OPENCODE_WEB_BASIC_AUTH="Basic '
          printf 'opencode:%s' "$(cat ${cfg.passwordFile} | tr -d '[:space:]')" | base64 -w0
          printf '"\n'
        } > /run/opencode-web/caddy.env
      '';
    };
  };

in
{
  config = mkIf cfg.enable (mkMerge [
    {
      systemd.services = lib.mkMerge (map mkService instances);
    }

    # ── Tailnet exposure (tailscale serve) ───────────────────────────────────
    (mkIf cfg.tailnetServe.enable {
      systemd.services = lib.mkMerge (map mkServeService instances);
    })

    # ── Basic auth: feed the dashboard API handles through Caddy ────────────
    (mkIf (cfg.passwordFile != null) {
      systemd.services.opencode-web-auth-env = mkAuthEnvService."opencode-web-auth-env";
      # Route through the proxy module (Co1): extraCaddyEnvironmentFiles merges into the caddy unit
      my.services.proxy.extraCaddyEnvironmentFiles = [ "/run/opencode-web/caddy.env" ];
    })

    # ── Firewall ────────────────────────────────────────────────────────────
    (mkIf (any (i: i.openFirewall) instances) {
      networking.firewall.allowedTCPPorts =
        map (i: i.port) (filter (i: i.openFirewall) instances);
    })

    # ── Dashboard section (consumed by my.services.proxy) ───────────────────
    (mkIf cfg.dashboard.enable {
      my.services.proxy.dashboard.opencode = dashboardInstances;
    })
  ]);
}
