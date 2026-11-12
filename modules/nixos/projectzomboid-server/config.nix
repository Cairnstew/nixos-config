# modules/nixos/projectzomboid-server/config.nix
# Host-local wiring for the upstream nixos-projectzomboid-servers module.
#
# There are no `my.*` options here on purpose: the upstream module owns the whole
# option surface under `services.project-zomboid-servers.*`, and re-exporting it
# under `my.*` would mean duplicating every option and drifting out of sync on
# each `nix flake update`. What legitimately stays local is the handful of
# decisions that are about THIS config rather than about Project Zomboid: which
# disk holds the data, who may read it, and how the consoles reach the proxy.
{ config, flake, lib, pkgs, ... }:

let
  cfg = config.services.project-zomboid-servers;
  me = flake.config.me;

  # ── Client launcher ────────────────────────────────────────────────────────
  # The pack's Java mods need ZombieBuddy attached to the CLIENT's JVM, and the
  # only install path the mod documents is Steam's launch-options field:
  # per-machine, un-versioned, and lost whenever Steam's localconfig is reset or
  # the game moves to another machine. Keeping it here makes "launch the game"
  # one reproducible action that a Hyprland bind (or the desktop entry below)
  # can run.
  #
  # The delivery is `steam -applaunch`, which is exactly what the launch-options
  # field feeds anyway: projectzomboid.sh forwards "$@" to ProjectZomboid64,
  # which appends them to the JVM's own command line.
  #
  # POLICY is `prompt`, which is the agent's own default: one approval dialog per
  # unknown JAR, remembered by SHA-256 in ~/.zombie_buddy/mod_approvals.json.
  # `deny-new` is only correct AFTER that first approval pass — from a cold start
  # nothing is approved, so it would silently skip every Java mod. `allow-all` is
  # what the headless server must use (there is nobody to click); a desktop does
  # not need it. `frontend` is left at `auto`, which picks a Swing dialog here;
  # the server sets `frontend=console` for the same "who is there to answer"
  # reason.
  zombieBuddyJar = "${cfg.serverDir}/steamapps/workshop/content/108600/3619862853/mods/ZombieBuddy/libs/ZombieBuddy.jar";

  projectzomboidViewpoint = pkgs.writeShellApplication {
    name = "projectzomboid-viewpoint";
    runtimeInputs = [ pkgs.steam ];
    text = ''
      agent="${zombieBuddyJar}"
      if [ ! -r "$agent" ]; then
        echo "projectzomboid-viewpoint: missing $agent" >&2
        echo "The shared Workshop download is kept current by project-zomboid-install." >&2
        exit 1
      fi
      exec steam -applaunch ${cfg.package.steamAppId or "108600"} \
        "-javaagent:$agent=policy=prompt" -- "$@"
    '';
  };

  # Upstream deliberately knows about no reverse-proxy module — a standalone
  # flake cannot depend on someone's private option namespace. It exposes plain
  # data per web-console server instead (`webConsoleUpstreams`), and the
  # consumer maps that into whatever proxy it uses. This is that mapping.
  #
  # Inert while `web.enable` is false (the default): the list is empty, so
  # nothing is registered.
  #
  # NOTE the dynamic-key shape. `my.services.proxy.upstreams` is `attrsOf`, and
  # mkMerge on an attrsOf option merges the list's elements AS the attrset — so
  # each element must already be `{ <upstream name> = <definition>; }`.
  # Two plausible-looking alternatives both register nothing, silently:
  #   { inherit (u) port path …; name = u.name; }   # mkMerge splats port/path/
  #                                               # name as top-level keys
  #   lib.nameValuePair u.name { …; }              # yields { name = …; value = … }
  # `nix eval` shows the difference: upstreams = [ "name" "value" ] vs
  # upstreams = [ "pz-knox" ]. Upstream's README suggests the first form.
  pzUpstreams = lib.mkMerge (map
    (u: {
      ${u.name} = {
        inherit (u) port path stripPrefix displayName;
        # ttyd listens on `web.bind`, so the proxy has to target that address.
        # It must be an IP rather than an interface name.
        host = cfg.web.bind;
      };
    })
    cfg.webConsoleUpstreams);

  # The dashboard UI and API. Same shape as the console upstreams: a plain
  # loopback target registered on Caddy. The prefix is stripped, so the
  # service sees `/api/...` and its relative asset URLs resolve under
  # `/pz-admin/`.
  pzManageUpstream = lib.optionalAttrs cfg.manage.enable {
    pz-admin = {
      inherit (cfg.manage) port;
      path = "/pz-admin/";
      stripPrefix = true;
      displayName = "Project Zomboid dashboard";
      host = cfg.manage.bind;
    };
  };

  # The client-host ports to forward on the router. Read from the server
  # definition so the mapping cannot drift from what the game binds.
  pzHostPorts =
    let
      s = cfg.servers.viewpoint or { };
    in
    [
      (s.defaultPort or 16261)
      (s.udpPort or 16262)
    ];
in
{
  config = lib.mkIf cfg.enable {
    # Adopt the upstream catalogue wholesale. It is plain data (a flake output,
    # not a module), so wiring it costs no extra options and no import — and
    # packs stay versioned with the code that understands them instead of being
    # forked here. Today that is `vanilla-plus` and `survival-hard`.
    # mkDefault so a host can replace it or layer a local pack over it; to
    # cherry-pick instead, assign e.g.
    #   modpacks = { vanilla-plus = flake.inputs.project-zomboid-servers.modpacks.vanilla-plus; };
    #
    # dataDir: keep the server on the large SATA data disk instead of the NVMe
    # root. The dedicated-server download is several GB and PZ saves grow
    # without bound, so `/var` (upstream's default) would quietly fill the root
    # filesystem on this host. mkDefault so a per-host override still wins.
    services.project-zomboid-servers = {
      modpacks = lib.mkDefault flake.inputs.project-zomboid-servers.modpacks;
      dataDir = lib.mkDefault "/mnt/data/project-zomboid";
    };

    # The PZ server runs as `project-zomboid` and the launcher reads
    # pz-admin-password (servers/knox.nix → adminAccount.passwordFile) itself,
    # so the decrypted /run/agenix file has to be group-readable by it.
    #
    # The manifest cannot say so directly: agenix runs an unconditional
    # `chown owner:group` at activation, and the group only exists once
    # services.project-zomboid-servers is enabled. Declaring `project-zomboid`
    # in the manifest would therefore break `nixos-rebuild` on every host where
    # PZ is off. Root ownership works everywhere (the feature is dormant), and
    # this hands the group over the moment it matters.
    age.secrets.pz-admin-password = {
      group = lib.mkForce cfg.group;
      mode = lib.mkForce "0440";
    };

    # Upstream creates the system user and its group but never adds this repo's
    # primary user, which leaves `seanc` unable to read the data dir or attach
    # to the console sockets. Mirrors what the pre-upstream module did.
    users.groups.${cfg.group}.members = [ me.username ];

    # UPnP / SSDP. Project Zomboid's `upnp = true` asks the router to forward
    # its two UDP ports, but discovery is broken without this rule: the router
    # answers the SSDP `M-SEARCH` (sent from udp/1900 to 239.255.255.250) back
    # to an ephemeral local port, and `nixos-fw` sees that reply as a NEW
    # inbound packet — the outbound multicast is not a tracked flow — and drops
    # it. `upnpc -l` then reports "No IGD UPnP Device found" on a router whose
    # UPnP is in fact enabled, and no mapping is ever created.
    #
    # Restricted to this LAN's /24 and to SSDP's own source port, so it cannot
    # be replayed to reach any other local UDP socket. The subnet is written
    # down because the interface is DHCP (`networking.defaultGateway` is null),
    # so it is not derivable at eval time.
    networking.firewall.extraCommands = ''
      iptables -A nixos-fw -p udp -s 192.168.1.0/24 --sport 1900 -j nixos-fw-accept
    '';

    # Router port mapping for the client-host ports, WITHOUT Project Zomboid.
    #
    # `upnp = true` in the server config would be the natural way to ask, but
    # Build 42 has no UPnP implementation at all (the 42.21 jar contains no UPnP
    # class; the upstream module warns if the option is set), so the mapping is
    # kept here instead, with miniupnpc. The timer re-runs it because a mapping
    # is still lost on a router reboot; `upnpc -a` is idempotent and costs one
    # SSDP exchange.
    systemd.services.pz-upnp-forward = {
      description = "Forward the Project Zomboid client-host ports on the router (UPnP)";
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];

      serviceConfig = {
        Type = "oneshot";
        # The mappings outlive the unit; the timer is what re-establishes them.
        RemainAfterExit = false;
      };

      script = ''
        upnpc=${pkgs.miniupnpc}/bin/upnpc

        # The firewall rule above is what makes SSDP replies reach this process.
        # No IGD is a normal state (a router with UPnP off), not a failure.
        if ! "$upnpc" -l >/dev/null 2>&1; then
          echo "pz-upnp: no UPnP IGD on this network; skipping"
          exit 0
        fi

        lan_ip="$(${pkgs.iproute2}/bin/ip -4 route get 1.1.1.1 2>/dev/null \
          | ${pkgs.gnused}/bin/sed -nE 's/.* src ([0-9.]+).*/\1/p')"
        if [ -z "$lan_ip" ]; then
          echo "pz-upnp: no default-route source address; skipping"
          exit 0
        fi

        for port in ${lib.concatMapStringsSep " " toString pzHostPorts}; do
          # No description argument: this router rejects the whole request with
          # error 600 (Argument Value Invalid) when one is supplied. 718 then
          # means the mapping already exists, which is the steady state.
          if "$upnpc" -a "$lan_ip" "$port" "$port" UDP >/dev/null 2>&1; then
            echo "pz-upnp: $lan_ip:$port forwarded"
          else
            echo "pz-upnp: $port already mapped (or the router refused it)"
          fi
        done
      '';
    };

    systemd.timers.pz-upnp-forward = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "2min";
        OnUnitActiveSec = "30min";
      };
    };

    # Per-server ttyd consoles auto-register on the Caddy dashboard, e.g.
    # https://<host>.<tailnet>.ts.net/pz/knox/. Replaces the pre-upstream
    # `web.proxyUpstream` option, which upstream cannot express.
    #
    # Merged into ONE `my = { … }` rather than repeated `my.<path> = …` lines:
    # statix's W20 warns on the repeat, and the upstream module's own checks are
    # the only thing keeping the two in sync today.
    my = {
      services.proxy.upstreams = lib.mkMerge [ pzUpstreams pzManageUpstream ];

      homeManager = {
        # The Home Manager HALF of the upstream module. The NixOS module only
        # renders `clientHosts`; this runs it, writing `~/Zomboid/Server/<name>.ini`
        # and its SandboxVars into the client user's own home. It reads the pack
        # back off `osConfig`, so it is inert on a host with no `clientHosts`,
        # needs no activation hook, and writes no path down — the Steam library is
        # discovered rather than named here.
        extraModules = [ flake.inputs.project-zomboid-servers.homeModules.default ];

        # The launcher, on the user's PATH so a Hyprland `exec` and the desktop
        # entry both reach it by name. A desktop entry as well as a bind, because
        # the game is not only launched from the keyboard.
        extraConfig = {
          home.packages = [ projectzomboidViewpoint ];

          # `home.installMods` is deprecated upstream: a client-hosted world
          # gets its Workshop mods through the game's Host flow, which downloads
          # `WorkshopItems=` through Steam. It is left at its default (false).
          #
          # The shared dedicated-server download is still refreshed by hand with
          # `pz-client-mods` (back up `libraryfolders.vdf` first; see
          # GOTCHAS.md for the 2026-10-07 clobber):
          #
          #   nix run ~/Projects/nixos-projectzomboid-servers#pz-client-mods -- viewpoint
          #
          # Run it from a real directory, never /tmp: steamcmd is wrapped in
          # `steam-run`, whose sandbox has a PRIVATE /tmp.
          services.project-zomboid-servers.home = {
            steamLogin = "cairnsgerry";

            # `linkSteamWorkshop` no longer exists upstream: the client
            # enumerates mods through Steam's subscription list and never scans
            # the dedicated server's Workshop copy, so there is nothing to link.
          };

          xdg.desktopEntries.projectzomboid-viewpoint = {
            name = "Project Zomboid (Viewpoint)";
            comment = "Project Viewpoint Vanilla+ with the ZombieBuddy JVM agent";
            exec = "projectzomboid-viewpoint";
            categories = [ "Game" ];
            terminal = false;
          };
        };
      };
    };
  };
}
