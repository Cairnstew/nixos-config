{ config, lib, flake, ... }:

let
  cfg = config.my.programs.zed-editor;
  remote = import ./remote.nix { inherit lib; };

  tailnet = flake.config.tailnet or { };
  tailnetNames = builtins.attrNames tailnet;

  # Build the connections exactly as config.nix does. Exercising the real
  # builder is the point: the original bug (auto-generated entries in Zed's
  # snake_case shape being fed to a converter expecting the camelCase option
  # shape) was invisible until the option was enabled on a real host, because
  # nothing asserted on the generated output.
  connections = remote.buildConnections {
    inherit tailnet;
    username = flake.config.me.username;
    tailnetConnections = cfg.tailnetConnections;
    sshConnections = cfg.sshConnections;
  };

  # Hosts that opt into generation, i.e. what actually lands in settings.json.
  autoNames = remote.selectedTailnetNames {
    tailnetNames = tailnetNames;
    include = cfg.tailnetConnections.include;
    exclude = cfg.tailnetConnections.exclude;
    overrides = cfg.tailnetConnections.hosts;
  };

  generated = builtins.filter (c: lib.elem c.nickname autoNames) connections;

  # A per-host override may not refer to a host absent from flake.config.tailnet;
  # a typo there would otherwise silently do nothing.
  unknownOverrideNames = builtins.filter (name: !(tailnet ? ${name}))
    (builtins.attrNames cfg.tailnetConnections.hosts);

  # Tailnet keys named in include/exclude that do not exist — usually a typo or
  # a host removed from config.nix.
  unknownSelectedNames =
    builtins.filter (name: !(tailnet ? ${name}))
      (cfg.tailnetConnections.include ++ cfg.tailnetConnections.exclude);

  # Any connection entry with nothing to connect to.
  hostlessConnections = builtins.filter (c: c.host == null || c.host == "") connections;

  # Duplicate connection identities would render as two rows in the dialog.
  connectionKeys = map remote.connectionKey connections;
  duplicateKeys = builtins.filter
    (
      key: builtins.length (builtins.filter (k: k == key) connectionKeys) > 1
    )
    (lib.unique connectionKeys);

  # A fixture tailnet, so the auto-generation path is exercised on every host —
  # including hosts that leave `tailnetConnections.enable` off. This is the
  # regression guard for the original bug: the auto-generator emitted Zed's
  # snake_case shape while the converter read the camelCase option shape, so
  # `tailnetConnections.enable = true` threw
  # "attribute 'uploadBinaryOverSsh' missing" and broke evaluation. Nothing
  # enabled the option, so the path was never run and the bug shipped.
  fixtureTailnet = {
    server = {
      ip = "100.64.0.1";
      hostname = "server";
      magicDnsName = "server.tail1234.ts.net";
    };
    desktop = {
      ip = "100.64.0.2";
      hostname = "desktop";
      magicDnsName = null;
    };
    wsl = {
      ip = "100.64.0.3";
      hostname = "wsl";
      magicDnsName = "wsl.tail1234.ts.net";
    };
  };

  fixtureBase = {
    enable = true;
    hostField = "magicDnsName";
    include = [ ];
    exclude = [ ];
    defaultProjects = [ "~" ];
    uploadBinaryOverSsh = true;
    args = [ ];
    hosts = { };
  };

  fixtureConnections = remote.buildConnections {
    tailnet = fixtureTailnet;
    username = "seanc";
    sshConnections = [ ];
    tailnetConnections = fixtureBase;
  };

  fixtureZed = map remote.mkConnection fixtureConnections;

  byNickname = builtins.listToAttrs (map
    (c: {
      name = c.nickname;
      value = c;
    })
    fixtureZed);

  # Nicknames of the connections a given tailnetConnections config produces.
  # Select by nickname rather than list position: `attrNames` sorts keys, so
  # index 0 is "desktop", not "server".
  nicknamesFor = tailnetConnections:
    map (c: c.nickname)
      (remote.buildConnections {
        tailnet = fixtureTailnet;
        username = "seanc";
        sshConnections = [ ];
        inherit tailnetConnections;
      });

  # Applying the same config twice must give the same result.
  idempotent = remote.buildConnections
    {
      tailnet = fixtureTailnet;
      username = "seanc";
      sshConnections = [ ];
      tailnetConnections = fixtureBase;
    } == fixtureConnections;
in
{
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.fontSize > 0;
        message = "my.programs.zed-editor.fontSize must be positive.";
      }
      {
        assertion = cfg.tabSize > 0;
        message = "my.programs.zed-editor.tabSize must be positive.";
      }
      {
        assertion = cfg.preferredLineLength > 0;
        message = "my.programs.zed-editor.preferredLineLength must be positive.";
      }
      {
        assertion = cfg.autosaveDelay > 0;
        message = "my.programs.zed-editor.autosaveDelay must be positive.";
      }
      {
        assertion = cfg.git.inlineBlameDelay > 0;
        message = "my.programs.zed-editor.git.inlineBlameDelay must be positive.";
      }
      {
        assertion = cfg.fontFamily != "";
        message = "my.programs.zed-editor.fontFamily must not be empty.";
      }

      # ── Remote connections ──────────────────────────────────────────────
      {
        assertion = hostlessConnections == [ ];
        message = "my.programs.zed-editor: every sshConnections entry must set a non-empty `host` "
          + "(tailnetConnections.hosts entries may omit it — the address is derived from "
          + "flake.config.tailnet when `hostField` is set).";
      }
      {
        assertion = duplicateKeys == [ ];
        message = "my.programs.zed-editor: duplicate ssh connection(s) for "
          + "${builtins.concatStringsSep ", " duplicateKeys}. Each host/user/port triple may appear "
          + "once; an explicit sshConnections entry replaces the generated one automatically.";
      }
      {
        assertion = unknownOverrideNames == [ ];
        message = "my.programs.zed-editor.tailnetConnections.hosts refers to host(s) not in "
          + "flake.config.tailnet: ${builtins.concatStringsSep ", " unknownOverrideNames}.";
      }
      {
        assertion = unknownSelectedNames == [ ];
        message = "my.programs.zed-editor.tailnetConnections include/exclude names not in "
          + "flake.config.tailnet: ${builtins.concatStringsSep ", " unknownSelectedNames}. Fix the "
          + "spelling, or drop the name if the host was removed from config.nix.";
      }
      {
        assertion = !cfg.tailnetConnections.enable || tailnetNames != [ ];
        message = "my.programs.zed-editor.tailnetConnections.enable = true but flake.config.tailnet "
          + "defines no hosts. Declare them in config.nix, or set include/exclude explicitly.";
      }

      # ── Auto-generation behaviour (fixture-driven) ───────────────────────
      {
        assertion = builtins.length fixtureZed == 3;
        message = "tailnet auto-generation: expected one connection per tailnet host "
          + "(3 in the fixture), got ${builtins.toString (builtins.length fixtureZed)}.";
      }
      {
        assertion = byNickname.server.host == "server.tail1234.ts.net";
        message = "tailnet auto-generation: `magicDnsName` must be used verbatim as the host.";
      }
      {
        assertion = byNickname.desktop.host == "desktop";
        message = "tailnet auto-generation: a null magicDnsName must fall back to `hostname`.";
      }
      {
        assertion = byNickname.server.username == "seanc";
        message = "tailnet auto-generation: username must default to flake.config.me.username.";
      }
      {
        assertion = byNickname.server.upload_binary_over_ssh == true;
        message = "tailnet auto-generation: `upload_binary_over_ssh` must default from "
          + "tailnetConnections.uploadBinaryOverSsh (true) so offline remotes still work.";
      }
      {
        assertion = byNickname.server.projects == [{ paths = [ "~" ]; }];
        message = "tailnet auto-generation: `defaultProjects` must be wrapped in Zed's "
          + "projects/paths shape.";
      }
      {
        # No camelCase may leak into the JSON Zed reads.
        assertion = builtins.all
          (
            c: !(builtins.any (k: lib.hasPrefix "uploadBinary" k || lib.hasPrefix "localPort" k)
              (builtins.attrNames c))
          )
          fixtureZed;
        message = "tailnet auto-generation: option-shape (camelCase) keys leaked into Zed's "
          + "settings.json. Convert in remote.nix's mkConnection only.";
      }

      # include / exclude / per-host enable
      {
        assertion =
          nicknamesFor (fixtureBase // { include = [ "server" ]; }) == [ "server" ];
        message = "tailnet auto-generation: a non-empty `include` must act as a whitelist.";
      }
      {
        assertion =
          nicknamesFor
            (fixtureBase // {
              include = [ "server" "wsl" ];
              exclude = [ "wsl" ];
            }) == [ "server" ];
        message = "tailnet auto-generation: `exclude` must win over `include`.";
      }
      {
        assertion =
          nicknamesFor
            (fixtureBase // {
              hosts = {
                wsl = { enable = false; };
              };
            }) == [ "desktop" "server" ];
        message = "tailnet auto-generation: `hosts.<name>.enable = false` must drop that host.";
      }

      # Per-host overrides win over the tailnet-wide defaults.
      {
        assertion = (
          let
            r = remote.buildConnections {
              tailnet = fixtureTailnet;
              username = "seanc";
              sshConnections = [ ];
              tailnetConnections = fixtureBase // {
                defaultProjects = [ "~/default" ];
                hosts.server = {
                  projects = [{ paths = [ "~/git" ]; }];
                  portForwards = [
                    {
                      localPort = 8080;
                      remotePort = 80;
                      localHost = "0.0.0.0";
                      remoteHost = "docker-host";
                    }
                  ];
                };
              };
            };
            # Select the overridden host by nickname, not position.
            s = builtins.head (builtins.filter (c: c.nickname == "server")
              (map remote.mkConnection r));
          in
          s.projects == [{ paths = [ "~/git" ]; }]
          && s.port_forwards == [
            {
              local_port = 8080;
              remote_port = 80;
              local_host = "0.0.0.0";
              remote_host = "docker-host";
            }
          ]
          && s.projects != [{ paths = [ "~/default" ]; }]
        );
        message = "tailnet auto-generation: a per-host override must replace `defaultProjects` and "
          + "emit port_forwards with local_host/remote_host.";
      }

      # Explicit entries win over generated ones for the same host.
      {
        assertion = (
          let
            r = remote.buildConnections {
              tailnet = fixtureTailnet;
              username = "seanc";
              tailnetConnections = fixtureBase;
              sshConnections = [
                {
                  host = "server.tail1234.ts.net";
                  username = "seanc";
                  nickname = "Server (explicit)";
                  projects = [{ paths = [ "~/explicit" ]; }];
                  port = null;
                  args = [ ];
                  uploadBinaryOverSsh = false;
                  portForwards = [ ];
                }
              ];
            };
          in
          builtins.length r == 3
          && (builtins.elem "Server (explicit)" (map (c: c.nickname) r))
          && !(builtins.elem "server" (map (c: c.nickname) r))
        );
        message = "explicit sshConnections must replace the generated entry for the same host "
          + "(dedupe by host/user/port) rather than duplicating it.";
      }

      {
        assertion = idempotent;
        message = "tailnet auto-generation: buildConnections must be a pure function of its inputs.";
      }
    ];
  };
}
