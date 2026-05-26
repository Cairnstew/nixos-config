{ config, lib, pkgs, ... }:

let
  cfg = config.my.services.windowsIsoSync;
  inherit (lib) mkIf mkOption types;
  curl = "${pkgs.curl}/bin/curl";
  jq = "${pkgs.jq}/bin/jq";
  sevenz = "${pkgs.p7zip}/bin/7z";
  mount = "${pkgs.util-linux}/bin/mount";
  umount = "${pkgs.util-linux}/bin/umount";
  losetup = "${pkgs.util-linux}/bin/losetup";
in
{
  options.my.services.windowsIsoSync = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable weekly Windows ISO sync from GitHub releases";
    };

    githubRepo = mkOption {
      type = types.str;
      default = "Cairnstew/uup-dump-build-and-get-windows-iso";
      description = "GitHub repository in owner/repo format";
    };

    releaseTag = mkOption {
      type = types.str;
      default = "latest";
      description = "Release tag to download. Use 'latest' for the most recent release";
    };

    outputDir = mkOption {
      type = types.str;
      default = "/srv/pxe/windows";
      description = "Directory to extract Windows boot files into (bootmgfw.efi, boot/bcd, boot/boot.sdi, sources/boot.wim)";
    };

    onCalendar = mkOption {
      type = types.str;
      default = "weekly";
      description = "systemd onCalendar schedule for the sync timer";
    };
  };

  config = mkIf cfg.enable {
    systemd.services.windows-iso-sync = {
      description = "Windows ISO Sync — download release, reassemble ISO, extract boot files";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        StateDirectory = "windows-iso-sync";
        WorkingDirectory = "/var/lib/windows-iso-sync";
      };
      script = ''
        set -euo pipefail

        STAMP=".last_tag"
        OWNER="$(echo "${cfg.githubRepo}" | cut -d/ -f1)"
        REPO="$(echo "${cfg.githubRepo}" | cut -d/ -f2)"
        TMPDIR="$(mktemp -d)"
        LOOP_DEV=""
        MNT=""

        cleanup() {
          if [ -n "$MNT" ]; then
            ${umount} "$MNT" 2>/dev/null || true
          fi
          if [ -n "$LOOP_DEV" ]; then
            ${losetup} -d "$LOOP_DEV" 2>/dev/null || true
          fi
          rm -rf "$TMPDIR"
        }
        trap cleanup EXIT

        if [ "${cfg.releaseTag}" = "latest" ]; then
          API_URL="https://api.github.com/repos/$OWNER/$REPO/releases/latest"
        else
          API_URL="https://api.github.com/repos/$OWNER/$REPO/releases/tags/${cfg.releaseTag}"
        fi

        echo "[windows-iso-sync] Fetching release info from $API_URL"
        RELEASE_JSON="$(${curl} -sS "$API_URL")"
        TAG="$(${jq} -r '.tag_name // empty' <<< "$RELEASE_JSON")"

        if [ -z "$TAG" ] || [ "$TAG" = "null" ]; then
          echo "[windows-iso-sync] ERROR: Could not determine release tag" >&2
          ${jq} . <<< "$RELEASE_JSON" || true
          exit 1
        fi

        echo "[windows-iso-sync] Latest release tag: $TAG"

        if [ -f "$STAMP" ] && [ "$(cat "$STAMP")" = "$TAG" ]; then
          echo "[windows-iso-sync] Already at $TAG — nothing to do"
          exit 0
        fi

        echo "[windows-iso-sync] Downloading release assets..."
        cd "$TMPDIR"
        ${jq} -r '.assets[] | select(.name != null) | .browser_download_url' <<< "$RELEASE_JSON" \
          | while IFS= read -r url; do
            echo "  Downloading: $(basename "$url")"
            ${curl} -#SLO "$url"
          done

        echo "[windows-iso-sync] Reassembling ISO..."
        ISO_FILE=""

        if [ -f reassemble.sh ]; then
          echo "[windows-iso-sync] Running bundled reassembly script..."
          chmod +x reassemble.sh
          bash reassemble.sh
          ISO_FILE="$(ls -t *.iso 2>/dev/null | head -1 || true)"
        fi

        if [ -z "$ISO_FILE" ]; then
          PART="$(ls *.7z.001 *.zip.001 2>/dev/null | head -1 || true)"
          if [ -n "$PART" ]; then
            echo "[windows-iso-sync] Extracting split archive via 7z..."
            ${sevenz} x -y "$PART" 2>/dev/null
            ISO_FILE="$(ls -t *.iso 2>/dev/null | head -1 || true)"
          fi
        fi

        if [ -z "$ISO_FILE" ]; then
          PARTS="$(ls *.part* *.iso.* 2>/dev/null | sort || true)"
          if [ -n "$PARTS" ]; then
            echo "[windows-iso-sync] Concatenating split parts..."
            cat $PARTS > combined.iso
            ISO_FILE="combined.iso"
          fi
        fi

        if [ -z "$ISO_FILE" ]; then
          ISO_FILE="$(ls -t *.iso 2>/dev/null | head -1 || true)"
        fi

        if [ -z "$ISO_FILE" ] || [ ! -f "$ISO_FILE" ]; then
          echo "[windows-iso-sync] ERROR: No ISO file found after reassembly" >&2
          ls -la "$TMPDIR"
          exit 1
        fi

        echo "[windows-iso-sync] ISO ready: $ISO_FILE ($(du -h "$ISO_FILE" | cut -f1))"

        echo "[windows-iso-sync] Mounting ISO..."
        LOOP_DEV="$(${losetup} --show -f -P "$ISO_FILE")"
        MNT="$TMPDIR/mnt"
        mkdir -p "$MNT"
        ${mount} -o loop,ro "$LOOP_DEV" "$MNT"

        mkdir -p "${cfg.outputDir}"/boot

        if [ -f "$MNT/bootmgfw.efi" ]; then
          cp "$MNT/bootmgfw.efi" "${cfg.outputDir}/bootmgfw.efi"
          echo "[windows-iso-sync] Copied bootmgfw.efi"
        fi

        if [ -f "$MNT/boot/bcd" ]; then
          cp "$MNT/boot/bcd" "${cfg.outputDir}/boot/bcd"
          echo "[windows-iso-sync] Copied boot/bcd"
        else
          echo "[windows-iso-sync] WARNING: boot/bcd not found on ISO" >&2
        fi

        if [ -f "$MNT/boot/boot.sdi" ]; then
          cp "$MNT/boot/boot.sdi" "${cfg.outputDir}/boot/boot.sdi"
          echo "[windows-iso-sync] Copied boot/boot.sdi"
        else
          echo "[windows-iso-sync] WARNING: boot/boot.sdi not found on ISO" >&2
        fi

        if [ -f "$MNT/sources/boot.wim" ]; then
          cp "$MNT/sources/boot.wim" "${cfg.outputDir}/sources/boot.wim"
          echo "[windows-iso-sync] Copied sources/boot.wim"
        else
          echo "[windows-iso-sync] ERROR: sources/boot.wim not found on ISO" >&2
          exit 1
        fi

        echo "$TAG" > "$STAMP"
        echo "[windows-iso-sync] Sync complete — tag $TAG written to $STAMP"
      '';
    };

    systemd.timers.windows-iso-sync = {
      description = "Windows ISO Sync timer";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.onCalendar;
        Persistent = true;
      };
    };
  };
}
