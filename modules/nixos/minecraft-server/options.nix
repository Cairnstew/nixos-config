{ lib, ... }:

let
  inherit (lib) mkEnableOption mkOption types literalExpression;

  # Username → Minecraft UUID (dashed or undashed). Matches nix-minecraft's
  # coercedTo handling.
  uuidMap = types.attrsOf (
    types.coercedTo types.str (v: { uuid = v; }) (types.submodule {
      options.uuid = mkOption {
        type = types.strMatching "([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}|[0-9a-f]{32})";
        description = "Minecraft UUID (dashed or undashed).";
      };
    })
  );

  # Console management system. Mirrors nix-minecraft's `managementSystem`
  # submodule (camelCase here, translated to nix-minecraft's kebab-case in
  # config.nix). `systemdSocket` (FIFO + journald) is required for the web
  # console; `tmux` is the alternative for raw tmux-attach management.
  managementSystem = types.submodule {
    options = {
      tmux = {
        enable = mkEnableOption "management via a tmux socket";
        socketPath = mkOption {
          type = types.nullOr types.path;
          default = null;
          description = ''
            Directory holding per-server tmux socket files (null = upstream
            default /run/minecraft/<name>.sock).
          '';
        };
      };
      systemdSocket = {
        enable = mkEnableOption "management via systemd socket (journal + FIFO console)";
        socketPath = mkOption {
          type = types.nullOr types.path;
          default = null;
          description = ''
            Directory holding per-server FIFO files (null = upstream default
            /run/minecraft/<name>.stdin).
          '';
        };
      };
    };
  };

  webServer = types.submodule {
    options = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Expose a web console for this server.";
      };

      port = mkOption {
        type = types.nullOr types.port;
        default = null;
        description = ''
          Port for this server's web console. null = auto-allocate from
          <literal>web.portBase</literal> (base + sorted index).
        '';
      };
    };
  };
in
{
  options.my.services.minecraftServer = {
    enable = mkEnableOption "declarative Minecraft dedicated servers (nix-minecraft)";

    # EULA: Mojang requires explicit acceptance.
    eula = mkEnableOption "accept Mojang's Minecraft EULA (required to run a server)";

    dataDir = mkOption {
      type = types.path;
      default = "/mnt/data/minecraft";
      description = ''
        Base directory holding each server's world, mods and config.
        Each server lives in <literal>''${dataDir}/&lt;name&gt;</literal>.
        Point this at a large, fast disk (the server host uses /mnt/data).
      '';
    };

    # Drop directory for modpack zips. The primary way to provision mods:
    # export the pack from Prism Launcher as a zip and scp it here; the server
    # unpacks it on next start. Owned by the primary user so scp just works.
    packDir = mkOption {
      type = types.path;
      default = "/mnt/data/minecraft/packs";
      description = ''
        Directory where modpack <literal>.zip</literal> files are dropped
        (e.g. <literal>scp pack.zip seanc@server:''${packDir}/</literal> after
        exporting the instance from Prism Launcher). Referenced by each server's
        <option>servers.&lt;name&gt;.packZip</option>. Owned by the primary user
        (group <literal>minecraft</literal>) so scp works without sudo while the
        server can still read the zip.
      '';
    };

    # Default for all servers; per-server can override.
    openFirewall = mkEnableOption "open server ports in the firewall (default for all servers)";

    # Console management system for all servers (per-server can override).
    managementSystem = mkOption {
      type = managementSystem;
      default = { systemdSocket.enable = true; };
      description = "Console management system used by all servers. Defaults to systemd-socket (FIFO + journald), which the web console requires.";
    };

    web = {
      enable = mkEnableOption "per-server web consoles (ttyd over the server console FIFO)";

      portBase = mkOption {
        type = types.port;
        default = 7681;
        description = ''
          First port for web consoles; each server gets <literal>portBase +
          sorted-index</literal> unless overridden per-server. Avoid colliding
          with the existing <literal>my.services.ttyd</literal> (7681).
        '';
      };

      bind = mkOption {
        type = types.str;
        default = "127.0.0.1";
        description = ''
          IP address or interface to bind web consoles to. Default loopback —
          expose through the reverse proxy (see <option>web.proxyUpstream</option>)
          or set a tailnet IP.
        '';
      };

      user = mkOption {
        type = types.str;
        default = "minecraft-web";
        description = ''
          User the web console runs as. Created by this module and added to the
          <literal>minecraft</literal> group so it can write the server console
          FIFO; granted passwordless sudo for <literal>systemctl
          {start,stop,restart,status} minecraft-server-*</literal>.
        '';
      };

      username = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "HTTP basic-auth username for the consoles (set with passwordFile).";
      };

      passwordFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "File containing the HTTP basic-auth password (e.g. an agenix secret path).";
      };

      openFirewall = mkOption {
        type = types.bool;
        default = false;
        description = "Open the console ports in the firewall (needed when binding outside trusted interfaces).";
      };

      proxyUpstream = mkOption {
        type = types.bool;
        default = true;
        description = "Register each console as a reverse-proxy upstream (<literal>/mc/&lt;name&gt;/</literal>) on the proxy dashboard.";
      };
    };

    servers = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          enable = mkOption {
            type = types.bool;
            default = true;
            description = "Whether to run and manage this server.";
          };

          package = mkOption {
            type = types.package;
            description = ''
              Minecraft server package, e.g.
              <literal>pkgs.neoforgeServers.neoforge-1_21_1-21_1_238</literal>,
              <literal>pkgs.paperServers.paper-1_21_1</literal> or
              <literal>pkgs.vanillaServers.vanilla-1_21_1</literal>.
              Available from the nix-minecraft overlay.
            '';
            example = literalExpression ''
              pkgs.neoforgeServers.neoforge-1_21_1-21_1_238
            '';
          };

          jvmOpts = mkOption {
            type = types.str;
            default = "-Xmx4G -Xms2G";
            description = "JVM options for this server (e.g. '-Xms4G -Xmx8G').";
          };

          port = mkOption {
            type = types.port;
            default = 25565;
            description = "Game port. Merged into <option>serverProperties</option> as <literal>server-port</literal> (explicit serverProperties win).";
          };

          autoStart = mkOption {
            type = types.bool;
            default = true;
            description = "Whether to start this server at boot.";
          };

          serverProperties = mkOption {
            type = types.attrsOf (types.oneOf [ types.bool types.int types.str ]);
            default = { };
            description = ''
              Minecraft server.properties values (declarative). See
              https://minecraft.wiki/w/Server.properties
            '';
            example = literalExpression ''
              {
                max-players = 12;
                motd = "Dragon Technology";
                white-list = true;
                enable-query = true;
              }
            '';
          };

          whitelist = mkOption {
            type = uuidMap;
            default = { };
            description = "Username → UUID map of whitelisted players.";
            example = literalExpression ''
              { seanc = "01234567-89ab-cdef-0123-456789abcdef"; }
            '';
          };

          operators = mkOption {
            type = uuidMap;
            default = { };
            description = "Username → UUID map of operators (level 4 default).";
            example = literalExpression ''
              { seanc = "01234567-89ab-cdef-0123-456789abcdef"; }
            '';
          };

          openFirewall = mkOption {
            type = types.bool;
            default = false;
            description = "Open this server's ports in the firewall. Set module-level openFirewall or per-server.";
          };

          packZip = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = ''
              Filename (or absolute path) of a modpack <literal>.zip</literal> in
              <literal>my.services.minecraftServer.packDir</literal> to unpack
              into this server's data dir. This is the primary way to provision
              mods: export the instance from Prism Launcher as a zip (Export →
              Modrinth pack → ".mrpack" works too — it is just a zip) and scp it
              to <literal>packDir</literal>. On start the module extracts the
              zip's <literal>mods</literal>, <literal>config</literal>,
              <literal>kubejs</literal>, <literal>scripts</literal>,
              <literal>datapacks</literal> and <literal>defaultconfigs</literal>
              into the data dir, but only when the zip changes (tracked by a
              SHA-256 stamp file) — restarting an unchanged server does not
              re-clobber runtime-modified config. Non-absolute values resolve
              against <literal>packDir</literal>. Can be combined with
              <option>pack</option> (zip extracted first, pack symlinked after
              so pack wins on conflicts).
            '';
            example = "dragon-technology.mrpack";
          };

          restartOnZipChange = mkOption {
            type = types.bool;
            default = true;
            description = ''
              Automatically restart this server when its <option>packZip</option>
              changes, is replaced or first appears in <literal>packDir</literal>.
              A <literal>systemd.path</literal> unit watches the zip file; when
              it changes the server is restarted and the new pack is re-unpacked
              by <literal>extraStartPre</literal>. The restart only fires when
              the zip's SHA-256 differs from the last unpacked pack (stamp
              file), so spurious events are ignored. Set to <literal>false</literal>
              to restart manually only. No effect when <option>packZip</option>
              is null.
            '';
          };

          pack = mkOption {
            type = types.nullOr (types.coercedTo types.package toString types.str);
            default = null;
            description = ''
              Runtime path (or a <literal>fetchModrinthModpack</literal>
              derivation) of a modpack content directory. Its
              <literal>mods</literal>, <literal>config</literal>,
              <literal>kubejs</literal>, <literal>scripts</literal>,
              <literal>datapacks</literal> and <literal>defaultconfigs</literal>
              subdirectories are symlinked into the server data dir at service
              start. A plain string is treated as a path on the server's disk
              (not copied into the Nix store) — suitable for large local packs.
              A derivation (e.g. <literal>pkgs.fetchModrinthModpack {...}</literal>)
              is fetched into the store at build time, which is how mods are
              provisioned declaratively on fresh machines. Null = no mods
              (vanilla). Can be used together with <option>packZip</option>
              (zip extracted first, pack symlinked after so pack wins on
              conflicts).
            '';
            example = "/mnt/data/minecraft/packs/dragon-technology";
          };

          migrateFrom = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = ''
              Path to a pre-existing server data dir (e.g. the old
              <literal>server-data/&lt;instance&gt;</literal> from the Prism repo)
              whose <literal>world/</literal> and <literal>usercache.json</literal>
              are copied into <literal>''${dataDir}/&lt;name&gt;</literal> on first
              start (only if no <literal>world/</literal> exists yet — idempotent).
              Use to preserve worlds when migrating to this module.
            '';
            example = "/mnt/data/prismlauncher/server-data/Dragon Technology";
          };

          extraSymlinks = mkOption {
            type = types.attrsOf types.path;
            default = { };
            description = ''
              Additional things to symlink into the server data dir, keyed by
              relative path, e.g. <literal>{ "world/datapacks/x" = ./x; }</literal>.
            '';
          };

          restart = mkOption {
            type = types.str;
            default = "on-failure";
            description = "systemd Restart policy for the server unit.";
          };

          managementSystem = mkOption {
            type = managementSystem;
            default = { };
            description = "Console management system for this server. Empty = inherit <literal>my.services.minecraftServer.managementSystem</literal>.";
          };

          web = mkOption {
            type = webServer;
            default = { };
            description = "Per-server web console settings (inherits module-level <literal>web</literal> unless overridden).";
          };
        };
      });
      default = { };
      description = "Per-server Minecraft definitions.";
    };
  };
}
