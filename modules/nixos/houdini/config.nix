{ config, lib, pkgs, flake, ... }:
let
  inherit (lib) mkIf;
  cfg = config.my.programs.houdini;
  me = flake.config.me.username;

  # SideFX API-key login licensing (https://www.sidefx.com/docs/houdini/licensing/login_licensing.html):
  # HOUDINI_API_KEY_FILE must contain "<client id> <client secret>" on one line.
  # The agenix secret is root-owned 0400 and KEY=VALUE formatted, so a boot
  # oneshot renders it into a user-readable file for hkey/Houdini to consume.
  apiKeyFile = "/var/lib/houdini/api-key";
  hasSidefxSecret = config.age.secrets ? "sidefx-app";
  localLicenseServerEnabled = cfg.localLicenseServer.enable || cfg.redeemNonCommercial.enable;
  unwrapped = cfg.package.passthru.unwrapped;
  sesinetdBin = "${unwrapped}/houdini/sbin/sesinetd";
  sesictrlBin = "${unwrapped}/houdini/sbin/sesictrl";

  # A clean FHS environment for sesinetd that properly execs into the target
  # and stays alive as systemd's main PID (unlike the Houdini bundle's FHS
  # wrapper which exits after spawning via container-init).
  # Patch sesinetd/sesictrl to use NixOS's dynamic linker so they can run
  # directly (no FHS sandbox needed). Add RUNPATH for their bundled dsolib.
  sesinetdPatched = pkgs.runCommand "sesinetd-patched"
    {
      nativeBuildInputs = [ pkgs.patchelf ];
      buildInputs = [ pkgs.gcc.cc.lib ];
    } ''
    mkdir -p $out/bin
    cp -L ${sesinetdBin} $out/bin/sesinetd
    chmod +w $out/bin/sesinetd
    patchelf --set-interpreter "$(cat ${pkgs.stdenv.cc}/nix-support/dynamic-linker)" \
             --add-rpath "${lib.makeLibraryPath [ pkgs.gcc.cc.lib ]}:${unwrapped}/dsolib" \
             $out/bin/sesinetd
  '';
  sesictrlPatched = pkgs.runCommand "sesictrl-patched"
    {
      nativeBuildInputs = [ pkgs.patchelf ];
      buildInputs = [ pkgs.gcc.cc.lib ];
    } ''
    mkdir -p $out/bin
    cp -L ${sesictrlBin} $out/bin/sesictrl
    chmod +w $out/bin/sesictrl
    patchelf --set-interpreter "$(cat ${pkgs.stdenv.cc}/nix-support/dynamic-linker)" \
             --add-rpath "${lib.makeLibraryPath [ pkgs.gcc.cc.lib ]}:${unwrapped}/dsolib" \
             $out/bin/sesictrl
  '';
  # hserver (local license client daemon, port 1714). Houdini refuses to run
  # without it ("license can't be found"), and it cannot survive inside the
  # FHS sandbox's PID namespace when daemonized — patchelf it like sesinetd
  # so it can run as a normal systemd service.
  hserverPatched = pkgs.runCommand "hserver-patched"
    {
      nativeBuildInputs = [ pkgs.patchelf ];
      buildInputs = [ pkgs.gcc.cc.lib ];
    } ''
    mkdir -p $out/bin
    cp -L ${unwrapped}/bin/hserver $out/bin/hserver
    chmod +w $out/bin/hserver
    patchelf --set-interpreter "$(cat ${pkgs.stdenv.cc}/nix-support/dynamic-linker)" \
             --add-rpath "${lib.makeLibraryPath [ pkgs.gcc.cc.lib ]}:${unwrapped}/dsolib" \
             $out/bin/hserver
  '';

  # The flake's package (houdini-nix) is already a buildFHSEnv wrapper — no
  # additional FHS wrapping needed.
  houdiniWrapped = cfg.package;

  # Launcher that bypasses bwrap entirely.  The buildFHSEnv (bubblewrap)
  # wrapper and the direct ld-linux path both hit the same deterministic
  # SIGSEGV in UI_Color::unref() during GUI init when the FHS rootfs's
  # libraries shadow Houdini's bundled copies via LD_LIBRARY_PATH.  See
  # the CRITICAL block below for the full explanation.
  #
  # Running houdini-bin directly via the FHS rootfs's ld-linux with dsolib/
  # prepended to LD_LIBRARY_PATH avoids the crash while preserving the FHS
  # library resolution (libstdc++, libgcc_s, Qt, etc. via /usr/lib64
  # symlinks).
  #
  # CRITICAL: Houdini's dsolib libraries use DT_RUNPATH (not DT_RPATH),
  # which means LD_LIBRARY_PATH takes precedence over RUNPATH per the ELF
  # spec.  The FHS rootfs contains different versions of 9 libraries that
  # Houdini also bundles in dsolib/ (TBB, zlib, zstd, png, bzip2, lzma,
  # OpenCL).  If the FHS rootfs versions load first via LD_LIBRARY_PATH,
  # the interface/version mismatch causes heap corruption — specifically
  # the UI_Color::unref() SIGSEGV.  The fix: put dsolib/ FIRST in
  # LD_LIBRARY_PATH so Houdini's bundled versions always win.
  #
  # The bwrap script (houdini-<ver>) embeds the fhsenv-rootfs store path.
  # We extract it at build time and use it to locate the FHS ld-linux and
  # the library symlinks.  LD_LIBRARY_PATH adds the ncurses5 compat lib
  # (needed by the OCL backend) on top.
  houdiniLauncher = pkgs.runCommand "houdini-launcher"
    {
      nativeBuildInputs = [ pkgs.makeWrapper pkgs.gnused pkgs.coreutils ];
    } ''
    mkdir -p $out/bin

    # Symlink non-houdini executables (hkey, hython, etc.) from the bwrap
    # package as-is — CLI tools work fine through bwrap.
    for exe in ${cfg.package}/bin/*; do
      name=$(basename "$exe")
      if [[ "$name" != "houdini" ]]; then
        ln -s "$exe" $out/bin/"$name"
      fi
    done

    # Extract the fhsenv-rootfs path from the bwrap script.
    BWRAP_SCRIPT=$(readlink -f ${cfg.package}/bin/houdini-22.0.368)
    FHS_ROOTFS=$(${pkgs.gnugrep}/bin/grep -oP '/nix/store/[a-z0-9]+-houdini-[^/]+-fhsenv-rootfs' "$BWRAP_SCRIPT" | head -1)
    HOUDINI_HFS="${unwrapped}"
    HOUDINI_BIN="$HOUDINI_HFS/bin/houdini-bin"
    NCURSES5="${pkgs.ncurses5}/lib"

    # Build the wrapper script with Nix paths baked in at build time.
    # Shell variables ($QT_QPA_PLATFORM etc.) are escaped so they expand
    # at runtime, not during the Nix build.
    cat > $out/bin/houdini <<EOF
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

    # FHS ld-linux resolves libraries via /usr/lib64 symlinks (glibc, gcc,
    # libX11, etc.) and LD_LIBRARY_PATH.  This gives us the same library
    # set as bwrap without the PID/mount namespace.
    #
    # dsolib/ MUST come first — Houdini's libraries use DT_RUNPATH (not
    # DT_RPATH), so LD_LIBRARY_PATH overrides RUNPATH resolution.  The
    # FHS rootfs has different versions of TBB, zlib, zstd, png, bzip2,
    # lzma, and OpenCL; loading those instead of Houdini's bundled copies
    # causes the UI_Color::unref() SIGSEGV.  By putting dsolib/ first,
    # conflicting SONAMEs resolve to Houdini's versions.  Non-conflicting
    # libs (libX11, libEGL, libfontconfig, etc.) still resolve from the
    # FHS rootfs because dsolib/ doesn't contain them.
    export LD_LIBRARY_PATH="$HOUDINI_HFS/dsolib:$FHS_ROOTFS/usr/lib64:$NCURSES5:/run/opengl-driver/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

    # Vulkan: Houdini bundles SwiftShader (software) in dsolib/ but rejects it
    # at startup — it needs the real GPU driver.  Point the Vulkan loader at
    # the system RADV ICD (via /run/opengl-driver) so it can dlopen()
    # libvulkan_radeon.so.  Keep SwiftShader as fallback.
    export VK_ICD_FILENAMES="/run/opengl-driver/share/vulkan/icd.d/radeon_icd.x86_64.json:$HOUDINI_HFS/dsolib/vk_swiftshader_icd.json"

    # Sanitize Qt environment:
    #  - QT_QPA_PLATFORM: Hyprland sets 'wayland'; Houdini's bundled Qt has
    #    no working Wayland plugin, so force xcb (XWayland).
    #  - QT_PLUGIN_PATH: session exports system Qt5/Qt6 plugin dirs; loading
    #    system plugins into Houdini's bundled Qt6 → SIGSEGV during UI init.
    #  - QT_QPA_PLATFORMTHEME: qt5ct is Qt5-only; leaks into Qt6.
    #  - QT_STYLE_OVERRIDE: Kvantum incompatible with UI_Color layout.
    unset QT_QPA_PLATFORM QT_PLUGIN_PATH QT_QPA_PLATFORMTHEME QT_STYLE_OVERRIDE
    export QT_QPA_PLATFORM="''${QT_QPA_PLATFORM:-xcb}"

    # Python tries to write .pyc bytecode caches next to the .py source files,
    # but the Nix store is read-only → hundreds of EROFS errors during startup.
    # Suppress .pyc writes (Python falls back to reading .py sources directly).
    export PYTHONDONTWRITEBYTECODE=1

    # lxml's etree.so has undefined symbols: libiconv, libiconv_open,
    # libiconv_close (GNU libiconv API).  Houdini bundles libiconv.so.2 in
    # dsolib/, but lxml has no DT_NEEDED for it, so the dynamic linker
    # never loads it → "undefined symbol: libiconv" ImportError at startup.
    # Preload it so the symbols are available when lxml loads.
    export LD_PRELOAD="$HOUDINI_HFS/dsolib/libiconv.so.2''${LD_PRELOAD:+:$LD_PRELOAD}"

    # Houdini's $HFS/qt/qml/ contains all Qt6 QML modules (QtQuick,
    # QtQuick.Layouts, houdini.pluto, houdini.ui, etc.).  Normally Qt
    # discovers these via the qt.conf "Prefix = ../qt" relative to the
    # binary, but we run houdini-bin via the FHS rootfs's ld-linux instead
    # of the normal wrapper — the different argv[0] path means Qt can't
    # locate qt.conf, so the QML import path never gets set.
    # Without this, StartupRoot.qml fails with "module not installed" for
    # every import (houdini.pluto, houdini.ui, QtQuick.Layouts) and the
    # StartupWindow throws a non-fatal error dialog on launch.
    export QML_IMPORT_PATH="$HOUDINI_HFS/qt/qml"

    # SUPPRESSION (not a root fix): Houdini's StartupWindow QML page
    # (StartupRoot.qml) hits a non-fatal Python error dialog during
    # initialization.  The traceback is truncated in the dialog — the
    # actual exception type/message is never shown.  Root cause: the
    # SharedState/Config/Theme/Prefs C++ singletons aren't registered
    # at the point QML tries to reference them via context properties;
    # they get set up fine later during normal GUI init.  The error is
    # harmless (Houdini opens and works after clicking OK), but the
    # dialog is annoying.  This env var suppresses the "Start Here"
    # splash/startup page, which is the only thing affected — it does
    # NOT suppress any other Python errors, dialogs, or functionality.
    export HOUDINI_NO_START_PAGE_SPLASH=1

    exec "$FHS_ROOTFS/usr/lib64/ld-linux-x86-64.so.2" "$HOUDINI_BIN" "$@"
    EOF
    chmod +x $out/bin/houdini
  '';
in
{
  config = mkIf cfg.enable {

    nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
      "houdini"
    ];

    environment.systemPackages = [ houdiniLauncher ];

    # Houdini's icon system creates temp SVG files in /tmp/houdini_temp/.
    # If this directory is owned by root (from a previous root-owned hserver
    # or sesinetd run), the user-level GUI process gets EACCES when trying
    # to create temp files — which cascades into the UI_Icon constructor
    # crash (SIGSEGV in UI_Color::unref()).  Ensure the directory exists
    # with 1777 permissions at boot so any user can write to it.
    systemd.services.houdini-temp-dir = {
      description = "Ensure /tmp/houdini_temp is writable by Houdini users";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${pkgs.coreutils}/bin/install -d -m 1777 /tmp/houdini_temp";
      };
    };

    environment.sessionVariables = {
      # HFS points to the unwrapped runtime root (not the FHS wrapper).
      # Never prepend $HFS/bin to PATH anywhere — that would shadow the
      # wrapped launcher in systemPackages with the raw runtime binaries.
      HFS = "${unwrapped}";
      HOUDINI_MAJOR_RELEASE = lib.versions.majorMinor cfg.package.passthru.unwrapped.version;
    } // lib.optionalAttrs (cfg.licenseServer != null) {
      sesi_license = cfg.licenseServer;
    } // lib.optionalAttrs (hasSidefxSecret && !localLicenseServerEnabled) {
      # Login licensing (HOUDINI_API_KEY_FILE) uses the OAuth app for server-to-sidefx
      # authentication. When using the local sesinetd (redeemNonCommercial), skip this
      # env var — the NC license is installed directly into sesinetd's database instead.
      HOUDINI_API_KEY_FILE = apiKeyFile;
    } // lib.optionalAttrs localLicenseServerEnabled {
      # Point Houdini at the local sesinetd for license checkout.
      sesi_license = "localhost:1715";
    } // cfg.extraEnv;

    # Render the agenix SideFX secret into the formats each consumer needs:
    #   - /var/lib/houdini/api-key        "<id> <secret>"  → HOUDINI_API_KEY_FILE (hkey/sesictrl)
    #   - ~/houdini<ver>/hserver.opt      ClientID/...     → hserver license daemon
    # hserver does NOT read HOUDINI_API_KEY_FILE (SideFX docs), so without
    # the .opt file login licensing fails even when the env var is set.
    # ── credential rendering ──────────────────────────────────────────────
    systemd.services.houdini-api-key = mkIf hasSidefxSecret {
      description = "Render SideFX API key for Houdini login licensing";
      wantedBy = [ "multi-user.target" ];
      after = [ "agenix.service" ];
      wants = [ "agenix.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      environment.HOME = "/home/${me}";
      script = ''
        install -d -m 700 -o ${me} ${builtins.dirOf apiKeyFile}
        client_id=$(${pkgs.gnugrep}/bin/grep -oP '(?<=^CLIENT_ID=).*' /run/agenix/sidefx-app || true)
        client_secret=$(${pkgs.gnugrep}/bin/grep -oP '(?<=^CLIENT_SECRET=).*' /run/agenix/sidefx-app || true)
        if [ -z "$client_id" ]; then
          # single-line "<id> <secret>" format
          read -r client_id client_secret < /run/agenix/sidefx-app
        fi
        if [ -z "$client_id" ] || [ -z "$client_secret" ]; then
          echo "houdini-api-key: could not parse CLIENT_ID/CLIENT_SECRET from /run/agenix/sidefx-app" >&2
          exit 1
        fi

        # 1) hkey/sesictrl env-var format
        printf '%s %s\n' "$client_id" "$client_secret" > ${apiKeyFile}
        chown ${me}: ${apiKeyFile}
        chmod 600 ${apiKeyFile}

        # 2) hserver option file — ClientID/ClientSecret here switches
        # hserver to SideFX cloud login licensing, which takes precedence
        # over sesi_license. Only render it when NOT using a local/remote
        # sesinetd; otherwise remove any stale copy.
        optdir="/home/${me}/houdini${lib.versions.majorMinor cfg.package.passthru.unwrapped.version}"
        install -d -m 755 -o ${me} "$optdir"
        ${if localLicenseServerEnabled || cfg.licenseServer != null then ''
          rm -f "$optdir/hserver.opt"
          echo "houdini-api-key: sesinetd in use — skipped hserver.opt (would force cloud login licensing)"
        '' else ''
          cat > "$optdir/hserver.opt" <<EOF
        ClientID = $client_id
        ClientSecret = $client_secret
          EOF
          chown ${me}: "$optdir/hserver.opt"
          chmod 600 "$optdir/hserver.opt"
        ''}

        # Restart hserver so it picks up credentials on next launch.
        # (-q = --quit; hserver is managed by houdini-hserver.service.)
        systemctl try-restart houdini-hserver.service 2>/dev/null || true
      '';
    };

    # ── hserver license client daemon ─────────────────────────────────────
    # Houdini requires a running hserver for license checkout; nothing in the
    # Houdini bundle or this module started one at boot, so after a reboot
    # plain `houdini` failed with "license can't be found".
    systemd.services.houdini-hserver = {
      description = "SideFX hserver local license client daemon";
      after = [ "network-online.target" ] ++ lib.optionals localLicenseServerEnabled [ "houdini-sesinetd.service" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        # hserver daemonizes by default (parent exits after forking the
        # daemon) — Type=forking lets systemd track the detached child.
        Type = "forking";
        User = "root";
        Group = "root";
        # systemd services don't read /etc/set-environment; without this
        # hserver defaults to SideFX's cloud license endpoint instead of
        # the local/remote sesinetd.
        Environment = lib.optionals (cfg.licenseServer != null || localLicenseServerEnabled) [
          "sesi_license=${if cfg.licenseServer != null then cfg.licenseServer else "localhost:1715"}"
        ];
        ExecStart = "${hserverPatched}/bin/hserver";
        # hserver caches its license-server choice in
        # /usr/lib/sesi/hserver/.sesi_licenses.pref (a cloud-mode run writes
        # serverhost=https://www.sidefx.com/... which overrides sesi_license).
        # Reset it before every start when using a sesinetd.
        ExecStartPre = mkIf localLicenseServerEnabled [
          "${pkgs.coreutils}/bin/install -d /usr/lib/sesi/hserver"
          ("${pkgs.bash}/bin/sh -c 'echo serverhost=" +
            (if cfg.licenseServer != null then "http://${cfg.licenseServer}" else "http://localhost:1715") +
            " > /usr/lib/sesi/hserver/.sesi_licenses.pref'")
        ];
        Restart = "on-failure";
        RestartSec = "3";
        PrivateTmp = true;
      };
    };

    # ── local sesinetd license server ─────────────────────────────────────
    systemd.services.houdini-sesinetd = mkIf localLicenseServerEnabled {
      description = "SideFX sesinetd local license server daemon";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        # sesinetd uses /usr/lib/sesi/ (no config relocation) and defaults to
        # --user sesinetd. Run as root; pass --user root to override the
        # binary default. Qt6 initializes QApplication even in daemon mode,
        # so set QT_QPA_PLATFORM=offscreen (no display at boot).
        # -D (--run-in-foreground) keeps the main process as systemd's PID;
        # Type=forking here caused an endless 5-minute start-timeout loop
        # because the parent never exits.
        Type = "simple";
        User = "root";
        Group = "root";
        Environment = [ "QT_QPA_PLATFORM=offscreen" ];
        ExecStart = "${sesinetdPatched}/bin/sesinetd -D --logToSystem=true --user root --group root";
        Restart = "on-failure";
        RestartSec = "3";
        # sesinetd writes to /usr/lib/sesi/ — keep hardening minimal.
        PrivateTmp = true;
        NoNewPrivileges = true;
      };
    };

    # ── NC license auto-renewal ───────────────────────────────────────────
    systemd.services.houdini-license-redeem = mkIf (cfg.redeemNonCommercial.enable && hasSidefxSecret) {
      description = "Renew Houdini Apprentice (NC) license via SideFX License API";
      after = [ "network-online.target" "houdini-sesinetd.service" ];
      wants = [ "network-online.target" "houdini-sesinetd.service" ];
      requiredBy = [ "houdini-license-redeem.timer" ];

      serviceConfig = {
        Type = "oneshot";
        # Root to read /run/agenix/sidefx-app (0400 root-owned). sesictrl
        # contacts sesinetd on loopback — no elevated privs needed for that.
        User = "root";
      };

      path = with pkgs; [ curl jq gnugrep coreutils ];

      script =
        let
          versionStr = cfg.redeemNonCommercial.version;
          productsStr = lib.concatStringsSep ";" cfg.redeemNonCommercial.products;
          serverName = cfg.redeemNonCommercial.serverName;
          serverCode = cfg.redeemNonCommercial.serverCode;
        in
        ''
          set -euo pipefail

          echo "houdini-license-redeem: starting NC license renewal"

          # --- Parse credentials ---
          client_id=$(${pkgs.gnugrep}/bin/grep -oP '(?<=^CLIENT_ID=).*' /run/agenix/sidefx-app || true)
          client_secret=$(${pkgs.gnugrep}/bin/grep -oP '(?<=^CLIENT_SECRET=).*' /run/agenix/sidefx-app || true)
          if [ -z "$client_id" ]; then
            read -r client_id client_secret < /run/agenix/sidefx-app
          fi
          if [ -z "$client_id" ] || [ -z "$client_secret" ]; then
            echo "FATAL: could not parse CLIENT_ID/CLIENT_SECRET from /run/agenix/sidefx-app" >&2
            exit 1
          fi

          # --- 1) OAuth2 token exchange ---
          echo "  obtaining OAuth token…"
          # SideFX /oauth2/application_token accepts Basic auth with empty body
          # for Authorization Code apps. No grant_type param needed.
          token=$(${pkgs.curl}/bin/curl -sfS \
            -X POST "https://www.sidefx.com/oauth2/application_token" \
            -u "$client_id:$client_secret" \
            | ${pkgs.jq}/bin/jq -r '.access_token // empty')
          if [ -z "$token" ]; then
            echo "FATAL: failed to obtain OAuth token" >&2
            exit 1
          fi

          # --- 2) Standard API call: get_non_commercial_license ---
          echo "  requesting NC license: ${productsStr} for ${serverName} (${versionStr})…"
          # SideFX API uses a form-encoded "json" field containing a JSON array:
          #   ["module.function", [positional_args], {keyword_args}]
          api_json=$(${pkgs.jq}/bin/jq -nc \
            --arg method "license.get_non_commercial_license" \
            --arg sn "${serverName}" \
            --arg sc "${serverCode}" \
            --arg ver "${versionStr}" \
            --arg prods "${productsStr}" \
            '[$method, [], {server_name: $sn, server_code: $sc, version: $ver, products: $prods}]')
          response=$(${pkgs.curl}/bin/curl -sfS \
            -X POST "https://www.sidefx.com/api/" \
            -H "Authorization: Bearer $token" \
            --data-urlencode "json=$api_json")

          # --- 3) Validate response ---
          error=$(echo "$response" | ${pkgs.jq}/bin/jq -r '.error // empty')
          if [ -n "$error" ]; then
            echo "FATAL: SideFX License API error: $error" >&2
            exit 1
          fi
          if echo "$response" | ${pkgs.jq}/bin/jq -e '.license_keys | length == 0' >/dev/null 2>&1; then
            echo "FATAL: API returned zero license keys (invalid server_code?)" >&2
            exit 1
          fi

          # --- 4) Install each LICENSE key ---
          # Use mapfile + for so sesictrl failures are not swallowed by a
          # pipeline (a failed install previously still exited 0).
          mapfile -t keys < <(echo "$response" | ${pkgs.jq}/bin/jq -r '.license_keys[]')
          failures=0
          for key in "''${keys[@]}"; do
            echo "  installing license key…"
            install_out=$(${sesictrlPatched}/bin/sesictrl install "$key" 2>&1) || true
            # "License has already been installed" is a successful no-op
            if ! grep -qiE 'Successfully installed|already been installed' <<<"$install_out"; then
              echo "  ERROR: sesictrl install failed: $install_out" >&2
              failures=$((failures+1))
            fi
          done

          # --- 5) Install SERVER key if present ---
          server_key=$(echo "$response" | ${pkgs.jq}/bin/jq -r '.server_key // empty')
          if [ -n "$server_key" ]; then
            echo "  installing server key…"
            server_out=$(${sesictrlPatched}/bin/sesictrl install "$server_key" 2>&1) || true
            if ! grep -qiE 'Successfully installed|already been installed' <<<"$server_out"; then
              echo "  ERROR: sesictrl install failed: $server_out" >&2
              failures=$((failures+1))
            fi
          fi

          if [ "$failures" -gt 0 ]; then
            echo "FATAL: $failures of $(( ''${#keys[@]} + 1 )) install(s) failed" >&2
            exit 1
          fi

          # --- 6) Verify licenses actually landed on the server ---
          # diagnostic's "Installed licenses:" table has data rows like
          # "    4588d6d0 Generic    HOUDINI-NC …" — an 8-hex-char LicID
          # followed by platform. Capture output first: `grep -q` in a
          # pipeline under pipefail false-negatives via SIGPIPE.
          diag_out=$(${sesictrlPatched}/bin/sesictrl diagnostic 2>&1) || true
          if ! grep -qE '^[[:space:]]+[[:xdigit:]]{8}[[:space:]]+[A-Za-z]' <<<"$diag_out"; then
            echo "FATAL: license table is empty after renewal — installs did not persist" >&2
            exit 1
          fi

          echo "houdini-license-redeem: Apprentice license renewal complete"
        '';
    };

    systemd.timers.houdini-license-redeem = mkIf (cfg.redeemNonCommercial.enable && hasSidefxSecret) {
      description = "Daily Houdini Apprentice license renewal timer";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
        RandomizedDelaySec = "1h";
      };
    };
  };
}
