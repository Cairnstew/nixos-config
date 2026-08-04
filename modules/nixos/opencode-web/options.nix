{ lib, pkgs, ... }:

let
  inherit (lib) mkEnableOption mkOption types literalExpression;

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
