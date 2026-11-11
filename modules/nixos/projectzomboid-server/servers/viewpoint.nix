# modules/nixos/projectzomboid-server/servers/viewpoint.nix
# Server: "viewpoint" — OwenOasis' "Project Viewpoint Vanilla+" modlist (Steam
# Workshop collection id 3812346398), running Project Viewpoint's first-person
# renderer via the ZombieBuddy Java-agent framework.
#
# Options are the upstream module's (services.project-zomboid-servers.*); the
# pack itself lives upstream in modpacks/viewpoint.nix.
{ config, lib, pkgs, ... }:
let
  # ZombieBuddy — the JVM agent every Java mod in this pack requires.
  #
  # Taken from the GitHub release rather than the Steam Workshop item, and
  # hash-pinned, for two reasons:
  #   1. The Workshop item (3619862853) has twice been hidden during Steam AV
  #      review; a hidden item cannot be fetched anonymously by steamcmd, which
  #      would take the whole server down with it.
  #   2. The version is load-bearing. ZombieBuddy <= 2.3.3 is SILENTLY broken on
  #      PZ 42.21.0 (it initialises, Lua mods load, and every Java mod is quietly
  #      dropped with no error). 2.3.4 is the first fixed release.
  #
  # This jar is byte-identical to the one inside the Workshop item, so pinning it
  # here does not diverge from what clients subscribe to.
  zombieBuddy = pkgs.fetchurl {
    url = "https://github.com/zed-0xff/ZombieBuddy/releases/download/v2.3.4/ZombieBuddy.jar";
    hash = "sha256-63m5h2MyAQczqODXzk/gN3hGBZqeKIWQKeKg+0SfbPI=";
  };
in
{
  services.project-zomboid-servers.servers.viewpoint = {
    enable = lib.mkDefault false;

    name = "viewpoint"; # -> Zomboid/Server/viewpoint.ini, Saves/Multiplayer/viewpoint
    description = "Project Viewpoint Vanilla+ (OwenOasis modlist) on NixOS";

    # Also render this pack for the game's own in-game Host button, which runs
    # the server inside the CLIENT's process. Same pack, same .ini, same mod
    # list — so hosting from the game never means writing the 170 `Mods=` ids
    # out a second time. The upstream module's Home Manager half writes those
    # files into `~/Zomboid`; it is imported for every host in
    # modules/nixos/projectzomboid-server/config.nix, because `~/Zomboid` is a
    # user path no system module may own.
    #
    # Independent of `enable`: this host runs no dedicated server for this pack,
    # and the pack still has to render.
    clientHost.enable = true;

    # Named to match `name` above, rather than left at the option's
    # `servertest` default, so the world is recognisable in the game's Host and
    # Load screens. Project Zomboid names BOTH the config and the save after
    # this — `Server/viewpoint.ini` and `Saves/Multiplayer/viewpoint` — so it is
    # the world's name, not just a filename.
    clientHost.name = "viewpoint";

    # Also merge the pack's ordered mod list into the client's own Mods menu as
    # a preset (default name: `viewpoint`). The Host flow loads `Mods=` only for
    # the hosted session; this is what enables Viewpoint's client-side code and
    # the UI mods outside a hosted world. The merge preserves any presets the
    # player made by hand, and missing mods are reported by the game's own
    # "missed mods" window.
    clientHost.preset.enable = true;

    # Open the two UDP ports for the client host. The server-level
    # `openFirewall` above is wired from the ENABLED servers, and this one is
    # `enable = false`, so without this the Host button binds 16261/16262 to a
    # closed firewall and nobody can reach the world.
    #
    # Necessary but not sufficient: PZ also tells joining clients the host's
    # PUBLIC address (`SERVER: server-address@<wan-ip>:16261`), so the router
    # still has to forward the same two ports. See docs/troubleshooting.md.
    clientHost.openFirewall = true;

    # Do not start at boot. Flip this to true (or `systemctl start
    # project-zomboid-viewpoint`) when you want it up. The console FIFO socket
    # still exists, so the web console can bring it up on demand.
    autoStart = false;

    modpack = "viewpoint";

    # ── Java mods ────────────────────────────────────────────────────────────
    # The pack's mods keep their JARs inside their own Workshop folders and are
    # referenced via mod.info's javaJarFile, so only the AGENT has to reach the
    # JVM. Project Viewpoint declares
    # `javaJarFile=media/java/client/Viewpoint.jar`, which ZombieBuddy skips on a
    # dedicated server — so the server loads no renderer and needs no GL, while
    # clients still get the first-person view.
    #
    # `policy=allow-all` is REQUIRED, not a preference. ZombieBuddy's default is
    # `policy=prompt`, which asks on stdin before loading each unknown JAR; under
    # systemd there is nobody to answer, so the server hangs at boot looking like
    # a slow start. `frontend=console` keeps it off any GUI path. `verbosity=1`
    # logs patch transformations, which is what makes a silent Java-mod failure
    # visible (ZombieBuddy logs "no active Java mods" when it is broken).
    #
    # NOT passed as part of jvmOpts by the caller: the option below is prepended
    # there, and the launcher's `--` separator is what routes it to the JVM.
    javaAgent = {
      jar = zombieBuddy;
      args = "policy=allow-all,frontend=console,verbosity=1";
    };

    # Heap for 438 Workshop items, including the Viewpoint asset pack. The
    # in-game Host ran this same pack at 5G with ~2.3G of the heap committed,
    # so 6G leaves headroom for 16 players. Must stay BELOW hardware.memoryMax
    # or the JVM is killed before it fills the heap.
    jvmOpts = "-Xmx6G -Xms3G -XX:+UseZGC -XX:-CreateCoredumpOnCrash";

    # Tuned for the dedicated `server` host (13 GiB total, no game client).
    # memoryHigh throttles with reclaim pressure before memoryMax is a hard
    # wall. If the box gets tight, stop docker-ollama for the session rather
    # than shrinking the heap below 5G.
    hardware = {
      memoryHigh = "8G";
      memoryMax = "10G";
      memorySwapMax = "2G";
      nice = 5;
    };

    defaultPort = 16261; # UDP, game
    udpPort = 16262; # UDP, direct connection — PZ binds two per instance
    # 27017, not 27015 (Minecraft's default RCON) or 27016 (the `knox` server).
    rconPort = 27017;
    openFirewall = true;
    public = true;
    publicName = "Project Viewpoint Vanilla+";
    maxPlayers = 16;

    open = true; # anyone may join

    # Join password, rendered into `~/Zomboid/Server/viewpoint.ini` by the
    # client-host activation (the value is read from the agenix secret at that
    # moment, so it never reaches the Nix store). One password for one friend;
    # this is the only gate — `open = true` still means no account is needed.
    passwordFile = config.age.secrets.pz-join-password.path;

    # `upnp = true` is deliberately NOT set: Build 42 dropped UPnP (the 42.21 jar
    # has no UPnP class, and the module warns if the option is set). The router
    # mapping is maintained by `systemd.services.pz-upnp-forward` in
    # modules/nixos/projectzomboid-server/config.nix instead.

    adminAccount = {
      username = "seanc";
      passwordFile = config.age.secrets.pz-admin-password.path;
    };

    # Server .ini overrides (win over the pack's defaultSettings).
    settings = {
      GlobalChat = true;
      AnnounceDeath = true;
      ShowFirstAndLastName = false;
    };

    # Sandbox overrides for the GLOBAL vanilla knobs only. Per-mod sandbox
    # entries are deliberately NOT set: every mod ships its own defaults in
    # media/sandbox-options.txt and the game applies them unaided, so writing 170
    # entries would be busywork that silently desyncs on each mod update.
    sandbox = {
      Zombies = 4; # Normal
      MultiHitZombies = true;
      StarterKit = true;

      # Zombie respawn: ON, but only in cells nobody has seen for 21 in-game
      # days. Project Zomboid has no per-safehouse zombie-respawn exclusion —
      # `RespawnUnseenHours` is the native lever, and it protects a base simply
      # because the base is loaded/seen whenever anyone is there or nearby.
      #
      # The values below are the vanilla "Normal" respawn rate (72h between
      # pulses, 10% of a cell's target per pulse) with only the unseen gate
      # raised from 16h to 504h. A base visited at least once every 21 in-game
      # days therefore never respawns; the rest of the map refills after a long
      # absence. Raise 504 to 8760 (a full in-game year) for a hard guarantee.
      ZombieRespawn = 2; # Normal preset; overridden below
      "ZombieConfig.RespawnHours" = 72;
      "ZombieConfig.RespawnUnseenHours" = 504; # 21 in-game days
      "ZombieConfig.RespawnMultiplier" = 0.1;
    };
  };
}
