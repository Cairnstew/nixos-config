# Options for my.services.projectZomboid — declarative Project Zomboid
# dedicated servers. Mimics the minecraft-server module: a per-server catalog in
# servers/, clean modpack definitions in modpacks/, SteamCMD install, FIFO
# console, hardware caps, and optional web console.
{ lib, pkgs, ... }:

let
  inherit (lib) mkEnableOption mkOption types literalExpression;

  # A single argument that gets passed to the PZ server JVM (e.g. "-Xmx6G").
  # Free-form because the JVM flag surface changes between builds.
  jvmOpts = mkOption {
    type = types.str;
    default = "-Xmx4G -Xms2G";
    description = ''
      Extra JVM flags for the server process (heap etc). The PZ dedicated server
      is a Java process; get this right or the server fails on memory. See the
      start-server.sh wrapper for the full default flag set.
    '';
    example = "-Xmx8G -Xms4G -XX:+UseZGC";
  };

  # A Workshop mod: just an ID (the URL / title are cosmetic, for humans).
  workshopMod = types.submodule {
    options = {
      id = mkOption {
        type = types.str;
        description = ''
          Steam Workshop item ID (numeric string). The server downloads the mod
          into <literal>steamapps/workshop/content/108600/&lt;id&gt;</literal>.
        '';
        example = "2625441155";
      };
      title = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Human-readable mod title (optional, for humans reading the pack).";
      };
    };
  };

  # Resource / scheduler caps applied to the server's systemd unit (same pattern
  # as the minecraft-server `hardware` submodule). All null = no cap.
  hardware = types.submodule {
    options = {
      memoryMax = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "systemd MemoryMax (e.g. \"10G\") — hard cgroup memory cap; OOM-kills the unit above this. null = unlimited.";
      };
      memoryHigh = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "systemd MemoryHigh (e.g. \"8G\") — soft memory throttle target. null = unlimited.";
      };
      memorySwapMax = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "systemd MemorySwapMax (e.g. \"2G\") — cap swap usage. null = unlimited.";
      };
      cpuQuota = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "systemd CPUQuota (e.g. \"200%\") — cap CPU to N% of one core. null = unlimited.";
      };
      nice = mkOption {
        type = types.nullOr types.int;
        default = null;
        description = "systemd Nice level. null = leave default.";
      };
      ioWeight = mkOption {
        type = types.nullOr types.int;
        default = null;
        description = "systemd IOWeight (1-10000). null = leave default.";
      };
    };
  };

  # Declarative fields of a <servername>.ini. Only `enable`-gated wiring goes
  # through the module below; everything else is user-passed key→value that is
  # rendered into the .ini. Using attrOf (oneOf str/int/bool/float) keeps the
  # surface open while still being type-checked.
  iniSetting = types.oneOf [ types.bool types.int types.float types.str ];

  settings = types.attrsOf iniSetting;

  # Declarative SandboxVars table — rendered into <name>_SandboxVars.lua.
  sandboxSettings = types.attrsOf iniSetting;

  # A whitelist / admin / moderator list is a comma-separated list of usernames.
  nameList = types.listOf types.str;
in
{
  options.my.services.projectZomboid = {
    enable = mkEnableOption "declarative Project Zomboid dedicated servers (SteamCMD app 380870)";

    # ── Runtime / packages ───────────────────────────────────────────────────
    user = mkOption {
      type = types.str;
      default = "project-zomboid";
      description = "System user under which the (shared) server install and all servers run.";
    };

    group = mkOption {
      type = types.str;
      default = "project-zomboid";
      description = "System group.";
    };

    dataDir = mkOption {
      type = types.path;
      default = "/mnt/data/project-zomboid";
      description = ''
        Base directory. The SteamCMD server install (app 380870) lives in
        <literal>''${dataDir}/server</literal> (shared by all servers) and each
        server's <literal>Zomboid</literal> home lives in
        <literal>''${dataDir}/&lt;name&gt;</literal>. Point this at a large,
        fast disk.
      '';
    };

    steamcmd = mkOption {
      type = types.package;
      default = pkgs.steamcmd;
      defaultText = literalExpression "pkgs.steamcmd";
      description = "steamcmd package used to install/update the server.";
    };

    steamRun = mkOption {
      type = types.package;
      default = pkgs.steam-run;
      defaultText = literalExpression "pkgs.steam-run";
      description = ''
        FHS wrapper (steam-run) used to execute the server binary with its
        expected Steam runtime.
      '';
    };

    # ── Server install / update ──────────────────────────────────────────────
    updateOnStart = mkEnableOption "run a steamcmd update of app 380870 at every server start";

    updateSchedule = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "daily";
      description = ''
        If set, run a steamcmd update on a systemd timer with this calendar spec
        and restart all servers afterwards. Null disables the timer (updates
        only happen via updateOnStart).
      '';
    };

    # ── Modpack definitions ──────────────────────────────────────────────────
    # Declared in modpacks/ as one file per named pack (the catalog). Each pack
    # bundles a set of Steam Workshop mods + local mods + optional default
    # server settings. A server picks one via servers.<name>.modpack.
    modpacks = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          description = mkOption {
            type = types.str;
            default = "";
            description = "Human-readable description of the pack.";
          };
          workshopMods = mkOption {
            type = types.listOf workshopMod;
            default = [ ];
            description = "Steam Workshop mods this pack installs (order is preserved, used for the WorkshopItems= list).";
          };
          mods = mkOption {
            type = types.listOf types.str;
            default = [ ];
            description = ''
              Local / bundled mod folder names (the <literal>Mods=</literal>
              list). These come from the shared server install's
              <literal>Zomboid/mods</literal> (or Workshop subfolders) — see the
              module README for how to add non-Workshop mods.
            '';
          };
          defaultSettings = mkOption {
            type = settings;
            default = { };
            description = ''
              Default <literal>.ini</literal> settings applied to any server that
              uses this pack (a server's own <option>settings</option> win).
            '';
          };
          defaultSandbox = mkOption {
            type = sandboxSettings;
            default = { };
            description = ''
              Default SandboxVars applied to any server that uses this pack (a
              server's own <option>sandbox</option> win).
            '';
          };
        };
      });
      default = { };
      description = ''
        Named Project Zomboid modpacks. Each is a clean, git-tracked bundle of
        Steam Workshop items (and optional default server settings) that one or
        more servers can reference via <literal>servers.&lt;name&gt;.modpack</literal>.
        Declared in <literal>modules/nixos/projectzomboid-server/modpacks/</literal>.
      '';
    };

    # ── Per-server definitions ───────────────────────────────────────────────
    servers = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          enable = mkOption {
            type = types.bool;
            default = true;
            description = "Whether to run and manage this server.";
          };

          name = mkOption {
            type = types.str;
            default = "";
            description = ''
              Project Zomboid server name — the <literal>&lt;name&gt;.ini</literal>
              / <literal>&lt;name&gt;_SandboxVars.lua</literal> file names and the
              save folder. Defaults to the attribute name in <option>servers</option>.
            '';
          };

          description = mkOption {
            type = types.str;
            default = "";
            description = "Human-readable description (used in unit descriptions).";
          };

          # ── Mods ───────────────────────────────────────────────────────────
          modpack = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = ''
              Name of a modpack from <option>modpacks</option> to apply to this
              server (e.g. <literal>"vanilla-plus"</literal>). The pack's
              workshopMods/mods/defaultSettings/defaultSandbox are merged in.
              Inline <option>workshopMods</option>/<option>mods</option> can
              extend or override.
            '';
            example = "vanilla-plus";
          };

          workshopMods = mkOption {
            type = types.listOf workshopMod;
            default = [ ];
            description = ''
              Extra / override Steam Workshop mods for this server (merged after
              the modpack's). Sets <literal>WorkshopItems=</literal> in the .ini.
            '';
          };

          mods = mkOption {
            type = types.listOf types.str;
            default = [ ];
            description = "Extra / override local mod folder names (merged after the modpack's). Sets Mods= in the .ini.";
          };

          # ── Connection / network ───────────────────────────────────────────
          map = mkOption {
            type = types.str;
            default = "Muldraugh, KY";
            description = "Map name (the folder in media/maps). Defaults to the classic Muldraugh start.";
          };

          defaultPort = mkOption {
            type = types.port;
            default = 16261;
            description = "Game port (DefaultPort in the .ini, UDP). Each server needs two free UDP ports (this and udpPort).";
          };

          udpPort = mkOption {
            type = types.port;
            default = 16262;
            description = "Direct-connection UDP port (UDPPort in the .ini). Pairs with defaultPort.";
          };

          rconPort = mkOption {
            type = types.port;
            default = 27015;
            description = "RCON TCP port (RCONPort). If unset/0 the module leaves RCON disabled by default.";
          };

          openFirewall = mkEnableOption "open this server's ports (defaultPort UDP + udpPort UDP) in the firewall";

          public = mkOption {
            type = types.nullOr types.bool;
            default = null;
            description = "Public=true/false — show in the in-game browser. null = leave the .ini default.";
          };

          publicName = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "PublicName — name shown in the server browser.";
          };

          maxPlayers = mkOption {
            type = types.int;
            default = 32;
            description = "MaxPlayers — max concurrent players (admins excluded). PZ warns above 32.";
          };

          # ── The actual server config ───────────────────────────────────────
          settings = mkOption {
            type = settings;
            default = { };
            description = ''
              Declarative <literal>&lt;name&gt;.ini</literal> overrides (e.g.
              <literal>{ PVP = true; PauseEmpty = true; }</literal>). These win
              over the modpack's defaultSettings and are written on every start.
            '';
          };

          sandbox = mkOption {
            type = sandboxSettings;
            default = { };
            description = ''
              Declarative <literal>&lt;name&gt;_SandboxVars.lua</literal>
              overrides (e.g. <literal>{ Zombies = 3; DayLength = 4; }</literal>).
              Merged over the modpack's defaultSandbox and written on start.
            '';
          };

          # ── Access control ────────────────────────────────────────────────
          open = mkOption {
            type = types.nullOr types.bool;
            default = null;
            description = "Open=true — anyone may join. false = whitelist required. null = leave default.";
          };

          whitelist = mkOption {
            type = nameList;
            default = [ ];
            description = "Usernames allowed to join when Open=false (comma-separated Whitelist= in the .ini).";
          };

          admins = mkOption {
            type = nameList;
            default = [ ];
            description = "Admin usernames (Users= in the .ini).";
          };

          passwordFile = mkOption {
            type = types.nullOr types.path;
            default = null;
            description = ''
              Path to a file (e.g. an agenix secret) whose contents set the
              <literal>Password=</literal> (join password). null = no join
              password. This overrides the admin password prompt by pre-seeding
              the config.
            '';
          };

          # ── Process / lifecycle ────────────────────────────────────────────
          jvmOpts = jvmOpts;

          autoStart = mkOption {
            type = types.bool;
            default = true;
            description = "Start this server at boot (wantedBy multi-user.target).";
          };

          restart = mkOption {
            type = types.str;
            default = "on-failure";
            description = "systemd Restart policy for the server unit.";
          };

          hardware = mkOption {
            type = hardware;
            default = { };
            description = "Hardware / resource limits for this server (systemd cgroup caps + scheduler niceness).";
          };

          extraServiceConfig = mkOption {
            type = types.attrs;
            default = { };
            description = "Extra systemd serviceConfig attributes merged onto the server unit. Beware: the server runs via steam-run (bwrap) so avoid strict sandboxing.";
          };

          opencodeWeb = mkOption {
            type = types.bool;
            default = true;
            description = "Give this server a ttyd web console (module-level web.enable must also be on).";
          };
        };
      });
      default = { };
      description = "Per-server Project Zomboid definitions.";
    };

    # ── Web console (ttyd over the server FIFO) ──────────────────────────────
    web = {
      enable = mkEnableOption "per-server ttyd web consoles";

      portBase = mkOption {
        type = types.port;
        default = 7681;
        description = ''
          First console port; each web-enabled server gets portBase + sorted
          index unless overridden per-server. Avoid colliding with the existing
          my.services.ttyd (7681) and the minecraft web consoles.
        '';
      };

      bind = mkOption {
        type = types.str;
        default = "127.0.0.1";
        description = "IP/interface to bind web consoles to. Default loopback — expose via the proxy or a tailnet IP.";
      };

      user = mkOption {
        type = types.str;
        default = "project-zomboid-web";
        description = "User the web console runs as (added to the PZ group, granted scoped sudo for systemctl on the PZ units).";
      };

      username = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "HTTP basic-auth username (set with passwordFile).";
      };

      passwordFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "File containing the HTTP basic-auth password (e.g. an agenix secret path).";
      };

      openFirewall = mkOption {
        type = types.bool;
        default = false;
        description = "Open the console ports in the firewall.";
      };

      proxyUpstream = mkOption {
        type = types.bool;
        default = true;
        description = "Register each console as a reverse-proxy upstream (<literal>/pz/&lt;name&gt;/</literal>) on the proxy dashboard.";
      };
    };

    # ── OpenCode integration ─────────────────────────────────────────────────
    opencode = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Add Project Zomboid modpack/server utilities to the user's opencode
          config (my.programs.opencode): the <literal>pz-modpack-status</literal>
          tool (inspect a named modpack's Workshop items / .ini surface) and the
          <literal>pz-modpack</literal> skill. Set false to keep opencode untouched.
        '';
      };
    };
  };
}
