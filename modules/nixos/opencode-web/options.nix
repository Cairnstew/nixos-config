{ config, lib, pkgs, ... }:

let
  inherit (lib) mkEnableOption mkOption types literalExpression;

  cfg = config.my.services.opencodeWeb;

  instanceOptions = {
    port = mkOption {
      type = types.nullOr types.port;
      default = null;
      description = "Listen port for this instance. When null, auto-allocated from <option>basePort</option>.";
    };

    servePort = mkOption {
      type = types.nullOr types.port;
      default = null;
      description = "Tailnet HTTPS port for this instance (via tailscale serve). When null, auto-allocated from <option>tailnetServe.basePort</option>.";
    };

    hostname = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Bind address for this instance. When null, uses the global <option>hostname</option>.";
    };

    openFirewall = mkOption {
      type = types.nullOr types.bool;
      default = null;
      description = "Open this instance's port in the firewall. When null, uses the global <option>openFirewall</option>.";
    };

    extraArgs = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [ "--cors" "https://app.example.com" ];
      description = "Extra CLI arguments passed to <literal>opencode web</literal> for this instance.";
    };
  };
in
{
  options.my.services.opencodeWeb = {
    enable = mkEnableOption "opencode web — browser UI for opencode, one systemd instance per synced repo";

    user = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''
        User to run the opencode web servers as. Must have opencode configured
        (<option>my.programs.opencode</option>) — the server reads that user's
        <filename>~/.config/opencode</filename>, <filename>auth.json</filename>,
        skills and MCP servers. Usually the primary user.
      '';
    };

    package = mkOption {
      type = types.package;
      default = pkgs.opencode;
      defaultText = literalExpression "pkgs.opencode";
      description = "The opencode package to use.";
    };

    repos = mkOption {
      type = types.listOf types.str;
      default = [ "nix-config" ];
      example = [ "nix-config" "sillytavern" ];
      description = ''
        Repositories (keys of <option>my.services.gitRepoSync.repos</option>) to
        serve. Each repo gets its own opencode web instance running inside that
        repo's checkout, so the web UI opens on the synced repo by default.
        The default serves the <literal>nix-config</literal> repo.
      '';
    };

    instances = mkOption {
      type = types.attrsOf (types.submodule instanceOptions);
      default = { };
      description = "Per-repo instance overrides, keyed by repo name.";
    };

    basePort = mkOption {
      type = types.port;
      default = 4200;
      description = "First auto-allocated port. Repos are assigned basePort, basePort+1, … in sorted order.";
    };

    hostname = mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = "Default bind address for all instances. Use 0.0.0.0 or a tailnet IP for remote access.";
    };

    openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = "Open instance ports in the firewall by default.";
    };

    passwordFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      example = "/run/agenix/opencode-web-password";
      description = ''
        File whose contents become <literal>OPENCODE_SERVER_PASSWORD</literal>
        (HTTP basic auth, username <literal>opencode</literal>). Required before
        exposing instances on the network. Leave <literal>null</literal> for
        localhost-only use.
      '';
    };

    dashboard = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Register instances in the proxy dashboard's OpenCode section.";
      };

      baseUrl = mkOption {
        type = types.str;
        default = "http://localhost";
        example = "http://server.tail685690.ts.net";
        description = ''
          URL base used for dashboard links to each instance's web UI
          (<literal>href = &lt;baseUrl&gt;:&lt;port&gt;/</literal>). Change to a
          tailnet hostname/IP when the dashboard is viewed from a different
          machine than the opencode instances. With <option>tailnetServe</option>
          enabled the dashboard builds tailnet links automatically from the
          current page's hostname instead.
        '';
      };
    };

    memoryHigh = mkOption {
      type = types.nullOr types.str;
      default = "4G";
      example = "4G";
      description = ''
        Soft memory limit (<literal>MemoryHigh</literal>) for each opencode web
        service. Teammates spawned by the ensemble run inside the same systemd
        unit cgroup, so this bounds a whole browser team. Set to
        <literal>null</literal> to leave the unit uncapped.
      '';
    };

    memoryMax = mkOption {
      type = types.nullOr types.str;
      default = "8G";
      example = "8G";
      description = ''
        Hard memory limit (<literal>MemoryMax</literal>) for each opencode web
        service. When the cgroup exceeds this the kernel OOM-kills the largest
        member (usually a teammate) instead of the whole host. Set to
        <literal>null</literal> to leave the unit uncapped.
      '';
    };

    memorySwapMax = mkOption {
      type = types.nullOr types.str;
      default = "4G";
      example = "4G";
      description = ''
        Per-unit swap limit (<literal>MemorySwapMax</literal>). Without this a
        memory-stressed team can push the cgroup deep into system swap and trip
        systemd-oomd's global <literal>SwapUsedLimit</literal> (default 90%),
        which kills the ENTIRE unit — web server and every teammate at once —
        the "blank browser / can't send messages" incident of 2026-08-05
        (peak 4.3G memory + 5.8G swap). Capping swap makes the kernel OOM-kill
        a single largest member (a teammate) inside the cgroup instead, so the
        web session survives. Set <literal>null</literal> to leave swap
        uncapped.
      '';
    };

    oomd = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Opt each opencode web unit out of systemd-oomd's wholesale kills by
          setting <literal>ManagedOOMMemoryPressure=never</literal> and
          <literal>ManagedOOMSwap=never</literal>. Degradation then falls to
          the kernel cgroup OOM-killer (bounded by <option>memoryHigh</option> /
          <option>memoryMax</option> / <option>memorySwapMax</option>), which
          kills one process at a time — a teammate, not the web server — so the
          browser session survives a memory spike instead of going blank.
        '';
      };
    };

    sessionGate = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Refuse to start the opencode web service while a terminal opencode
          session is running (and vice versa — see
          <option>my.programs.opencode.sessionGate</option>). Both sessions
          share <filename>~/.config/opencode</filename> and the ensemble state
          DB, so running them concurrently corrupts team orchestration.
        '';
      };

      lockPath = mkOption {
        type = types.path;
        default = "${config.users.users.${cfg.user}.home or "/home/${cfg.user}"}/.local/share/opencode/terminal.lock";
        description = ''
          Lock file written by a terminal opencode session (its PID) that the
          web service checks before starting. Must match
          <option>my.programs.opencode.sessionGate</option>.
        '';
      };
    };

    tailnetServe = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Expose each instance on the tailnet via
          <literal>tailscale serve --https &lt;port&gt;</literal>, so the web UI
          is reachable at <literal>https://&lt;host&gt;.ts.net:&lt;port&gt;/</literal>
          from any device on the tailnet. Each repo gets its own HTTPS port
          (modern Tailscale serve supports arbitrary ports).
        '';
      };

      basePort = mkOption {
        type = types.port;
        default = 8443;
        description = "First tailnet serve HTTPS port. Repos get basePort, basePort+1, … in sorted order.";
      };
    };
  };
}
