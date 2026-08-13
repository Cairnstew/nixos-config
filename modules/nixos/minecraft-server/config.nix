# Wires my.services.minecraftServer into services.minecraft-servers (nix-minecraft).
{ config, lib, flake, pkgs, ... }:

let
  inherit (lib) mkIf mapAttrs' nameValuePair concatStringsSep optionalAttrs;
  inherit (flake) inputs;
  inherit (inputs) nix-minecraft;
  me = flake.config.me;

  cfg = config.my.services.minecraftServer;

  # Content subdirectories a modpack zip can carry. `world*` is deliberately
  # excluded — a live world comes from migrateFrom or is freshly generated, and
  # must never be clobbered by a pack zip.
  packSubdirs = [ "mods" "config" "kubejs" "scripts" "datapacks" "defaultconfigs" ];

  # ── Content source: packZip (zip dropped in packDir) ──────────────────────
  # Extracts the zip into <dataDir>/<name>/.mc-pack only when its SHA-256
  # changes (stamped), then symlinks the content subdirs into the data dir. A
  # Prism instance zip wraps `minecraft/`; an mrpack/CurseForge pack wraps
  # `overrides/`; a bare modpack zip has the dirs at the root — all three
  # layouts are detected.
  zipExtractPre = name: srv:
    if srv.packZip == null then ""
    else
      let
        zipPath =
          if lib.hasPrefix "/" srv.packZip then srv.packZip
          else "${cfg.packDir}/${srv.packZip}";
        staging = "${cfg.dataDir}/${name}/.mc-pack";
        stamp = "${staging}.stamp";
      in
      ''
        ZIP='${zipPath}'
        STAGING='${staging}'
        STAMP='${stamp}'
        ROOT=""
        if [ ! -f "$ZIP" ]; then
          echo "[mc] WARN: packZip $ZIP not found — starting without it" >&2
        else
          NEW=$(${pkgs.coreutils}/bin/sha256sum "$ZIP" | ${pkgs.coreutils}/bin/cut -d' ' -f1)
          OLD=$(${pkgs.coreutils}/bin/cat "$STAMP" 2>/dev/null || true)
          if [ "$NEW" != "$OLD" ]; then
            echo "[mc] unpacking $ZIP ..."
            ${pkgs.coreutils}/bin/rm -rf "$STAGING"
            ${pkgs.coreutils}/bin/mkdir -p "$STAGING"
            if ! ${pkgs.unzip}/bin/unzip -q "$ZIP" -d "$STAGING"; then
              echo "[mc] WARN: failed to unzip $ZIP — leaving old pack in place" >&2
              ${pkgs.coreutils}/bin/rm -rf "$STAGING"
            else
              # Content root: Prism instance zip → minecraft/; mrpack/CF → overrides/.
              ROOT="$STAGING"
              if [ -d "$STAGING/minecraft" ]; then ROOT="$STAGING/minecraft"; fi
              if [ -d "$STAGING/overrides" ]; then ROOT="$STAGING/overrides"; fi
              if [ -d "$ROOT" ]; then
                echo "$NEW" > "$STAMP"
              fi
            fi
          fi
        fi
        # Symlink content subdirs (idempotent; no-op if unpack failed/zip missing).
        for d in ${concatStringsSep " " packSubdirs}; do
          if [ -n "$ROOT" ] && [ -d "$ROOT/$d" ]; then
            ${pkgs.coreutils}/bin/ln -sfn "$ROOT/$d" "$d"
          fi
        done
      '';

  # ── Content source: pack (plain dir or fetchModrinthModpack derivation) ───
  # Symlinked from a path on disk; placed after the zip so pack wins on conflicts.
  packStartPre = srv:
    if srv.pack == null then ""
    else
      concatStringsSep "\n" (builtins.map
        (d: ''
          if [ -d "${srv.pack}/${d}" ]; then
            ln -sfn "${srv.pack}/${d}" "${d}"
          fi
        '')
        packSubdirs);

  # One-time world migration from an existing server-data dir (idempotent).
  migratePre = srv:
    if srv.migrateFrom == null then ""
    else ''
      if [ ! -e world ] && [ -d "${srv.migrateFrom}/world" ]; then
        echo "[mc] migrating world from ${srv.migrateFrom} ..."
        cp -a "${srv.migrateFrom}/world" world
      fi
      if [ ! -f usercache.json ] && [ -f "${srv.migrateFrom}/usercache.json" ]; then
        cp -a "${srv.migrateFrom}/usercache.json" usercache.json
      fi
    '';

  # Extra user symlinks → data dir (path → relative target in data dir).
  symlinkPre = srv:
    concatStringsSep "\n" (lib.mapAttrsToList
      (rel: src: ''
        if [ -e "${src}" ]; then
          mkdir -p "$(dirname "${rel}")"
          ln -sfn "${src}" "${rel}"
        fi
      '')
      srv.extraSymlinks);

  # ── Console management system ─────────────────────────────────────────────
  # nix-minecraft expects `managementSystem."systemd-socket".enable` (kebab),
  # our options use camelCase. Resolve effective per-server system (per-server
  # override or module-level default) and translate.
  mkManagement = srv:
    let
      eff =
        if srv.managementSystem.systemdSocket.enable || srv.managementSystem.tmux.enable
        then srv.managementSystem else cfg.managementSystem;
      useSocket = eff.systemdSocket.enable;
      sockPath = eff.systemdSocket.socketPath;
      tmuxPath = eff.tmux.socketPath;
      base =
        if useSocket then {
          "systemd-socket".enable = true;
          tmux.enable = false;
        } else {
          tmux.enable = true;
          "systemd-socket".enable = false;
        };
    in
    base
    // optionalAttrs (useSocket && sockPath != null) {
      "systemd-socket".stdinSocket.path = _: sockPath;
    }
    // optionalAttrs (!useSocket && tmuxPath != null) {
      tmux.socketPath = _: tmuxPath;
    };

  mkServer = name: srv:
    nameValuePair name {
      inherit (srv)
        enable
        package
        jvmOpts
        autoStart
        whitelist
        operators
        openFirewall
        restart
        ;
      # `server-port` from the port option unless serverProperties sets it.
      serverProperties = { "server-port" = srv.port; } // srv.serverProperties;
      managementSystem = mkManagement srv;
      extraStartPre = concatStringsSep "\n" [
        (zipExtractPre name srv)
        (packStartPre srv)
        (migratePre srv)
        (symlinkPre srv)
      ];
    };

in
{
  imports = [
    nix-minecraft.nixosModules.minecraft-servers
  ];

  config = mkIf cfg.enable {
    # nix-minecraft's overlay provides vanillaServers/fabricServers/neoforgeServers/…
    nixpkgs.overlays = [ nix-minecraft.overlay ];

    services.minecraft-servers = {
      enable = true;
      inherit (cfg) eula dataDir openFirewall;
      servers = mapAttrs' mkServer cfg.servers;
    };

    # packDir: owned by the primary user so scp works without sudo, group
    # minecraft so the service user can read the zips. dataDir comes from
    # nix-minecraft's user creation.
    systemd.tmpfiles.rules = [
      "d ${cfg.packDir} 0770 ${me.username} minecraft - -"
    ];

    # Primary user in the minecraft group: dataDir is 0770 minecraft:minecraft
    # (from nix-minecraft), so without group membership the user cannot traverse
    # it to reach packDir — scp to packDir would fail with "Permission denied".
    users.groups.minecraft.members = [ me.username ];

    # dataDir + per-server dirs are created by a ROOT oneshot, NOT tmpfiles:
    # systemd-tmpfiles refuses to descend a path whose parent is owned by a
    # non-root user ("Detected unsafe path transition /mnt/data (owned by
    # seanc)") and silently skips the rule. nix-minecraft's tmpfiles rule for
    # ${dataDir}/${name} therefore never runs when dataDir lives under such a
    # parent, leaving the server's WorkingDirectory missing → systemd fails the
    # unit with status=200/CHDIR. This oneshot runs as root before every server
    # so the dirs always exist on fresh machines too.
    systemd.services.minecraft-server-prepare-dirs = {
      description = "Create Minecraft server data directories";
      wantedBy = [ "multi-user.target" ];
      before = map (name: "minecraft-server-${name}.service") (builtins.attrNames cfg.servers);
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        ${pkgs.coreutils}/bin/install -d -o minecraft -g minecraft -m 0770 ${cfg.dataDir}
        ${builtins.concatStringsSep "\n" (map (name: ''
          ${pkgs.coreutils}/bin/install -d -o minecraft -g minecraft -m 0770 ${cfg.dataDir}/${name}
        '') (builtins.attrNames cfg.servers))}
      '';
    };
  };
}
