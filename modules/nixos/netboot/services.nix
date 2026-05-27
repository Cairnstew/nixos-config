{ config, lib, pkgs, ... }:
let
  inherit (lib) mkIf mkMerge;
  cfg = config.my.services.netboot;
  httpRoot = cfg.httpRoot;

  netbootAdvance = pkgs.writeShellScriptBin "netboot-advance" ''
    set -euo pipefail

    PXE_DIR="${httpRoot}"
    STAGES_DIR="$PXE_DIR/stages"
    LEASE_FILE="/var/lib/misc/dnsmasq.leases"
    INTERFACE="${cfg.interface}"

    usage() {
      cat <<EOF
    Usage: netboot-advance <command> [args]

    Commands:
      list                    List all known machines and their current stage
      status  <mac>           Show current stage for a machine
      advance <mac>           Advance machine to the next boot stage
      reset   <mac>           Reset machine to the first boot stage
      set     <mac> <stage>   Set machine to a specific stage
      init                    Initialize symlinks for all configured machines
      scan                    Scan DHCP leases for active but unconfigured MACs

    Stages: discover, windows, nixos, done
    EOF
    }

    list_machines() {
      echo "Known machines:"
      for mac in "$STAGES_DIR"/*/; do
        mac_name="$(basename "$mac")"
        target="$(readlink "$PXE_DIR/$mac_name.ipxe" 2>/dev/null || echo "NOT INITIALIZED")"
        echo "  $mac_name → $target"
      done
    }

    show_status() {
      local mac="$1"
      local target
      target="$(readlink "$PXE_DIR/$mac.ipxe" 2>/dev/null || true)"
      if [ -z "$target" ]; then
        echo "Machine $mac: NOT INITIALIZED"
        echo "Run: netboot-advance init"
      else
        echo "Machine $mac: $target"
      fi
    }

    advance_stage() {
      local mac="$1"
      local current
      current="$(readlink "$PXE_DIR/$mac.ipxe" 2>/dev/null || true)"
      if [ -z "$current" ]; then
        echo "ERROR: $mac is not initialized. Run 'netboot-advance init' first." >&2
        exit 1
      fi
      # Extract stage name from symlink target
      local current_stage
      current_stage="$(basename "$current" .ipxe | sed 's/^stage-//')"

      local next_stage=""
      local found=0
      for s in discover windows nixos done; do
        if [ "$found" = "1" ]; then
          next_stage="$s"
          break
        fi
        if [ "$s" = "$current_stage" ]; then
          found=1
        fi
      done

      if [ -z "$next_stage" ]; then
        echo "ERROR: $mac is already at the final stage ($current_stage). Use 'reset' to restart." >&2
        exit 1
      fi

      local target="stages/$mac/stage-$next_stage.ipxe"
      if [ ! -f "$STAGES_DIR/$mac/stage-$next_stage.ipxe" ]; then
        echo "ERROR: Stage script not found: $STAGES_DIR/$mac/stage-$next_stage.ipxe" >&2
        exit 1
      fi

      ln -sf "$target" "$PXE_DIR/$mac.ipxe"
      echo "$mac advanced: $current_stage → $next_stage"
    }

    reset_stage() {
      local mac="$1"
      # Find first stage from available scripts
      local first_stage=""
      for s in discover windows nixos done; do
        if [ -f "$STAGES_DIR/$mac/stage-$s.ipxe" ]; then
          first_stage="$s"
          break
        fi
      done
      if [ -z "$first_stage" ]; then
        echo "ERROR: No stage scripts found for $mac" >&2
        exit 1
      fi
      ln -sf "stages/$mac/stage-$first_stage.ipxe" "$PXE_DIR/$mac.ipxe"
      echo "$mac reset to stage: $first_stage"
    }

    set_stage() {
      local mac="$1"
      local stage="$2"
      if [ ! -f "$STAGES_DIR/$mac/stage-$stage.ipxe" ]; then
        echo "ERROR: Stage script not found: $STAGES_DIR/$mac/stage-$stage.ipxe" >&2
        exit 1
      fi
      ln -sf "stages/$mac/stage-$stage.ipxe" "$PXE_DIR/$mac.ipxe"
      echo "$mac set to stage: $stage"
    }

    scan_leases() {
      echo "Scanning DHCP leases on $INTERFACE for active MACs..."
      if [ ! -f "$LEASE_FILE" ]; then
        echo "No lease file found at $LEASE_FILE"
        echo "Is dnsmasq running?"
        exit 1
      fi

      # Build list of configured MACs
      local configured=""
      for mac_dir in "$STAGES_DIR"/*/; do
        [ -d "$mac_dir" ] || continue
        configured="$configured $(basename "$mac_dir")"
      done

      local found=0
      while read -r expires mac ip hostname clientid; do
        [ -n "$mac" ] || continue
        # Skip configured machines
        if echo "$configured" | grep -q "$mac"; then
          continue
        fi
        # Skip expired leases (0 means infinite in dnsmasq)
        if [ "$expires" = "0" ] || [ "$expires" -gt "$(date +%s)" ]; then
          echo "  $mac  $ip  ''${hostname:-(no hostname)}"
          found=1
        fi
      done < "$LEASE_FILE"

      if [ "$found" = "0" ]; then
        echo "No unconfigured active MACs found."
        echo "Connect the target machine and power it on."
        echo "Then re-run: netboot-advance scan"
      fi
    }

    init_machines() {
      # Ensure PXE directory exists for per-mac symlinks
      mkdir -p "$PXE_DIR"

      # Walk stages directory and create missing symlinks
      for mac_dir in "$STAGES_DIR"/*/; do
        [ -d "$mac_dir" ] || continue
        mac="$(basename "$mac_dir")"
        symlink="$PXE_DIR/$mac.ipxe"

        if [ -L "$symlink" ] && [ -e "$symlink" ]; then
          echo "SKIP $mac — already initialized (→ $(readlink "$symlink"))"
        else
          # Find first stage script
          first=""
          for s in discover windows nixos done; do
            if [ -f "$mac_dir/stage-$s.ipxe" ]; then
              first="$s"
              break
            fi
          done
          if [ -n "$first" ]; then
            ln -sf "stages/$mac/stage-$first.ipxe" "$symlink"
            echo "INIT $mac → stage $first"
          else
            echo "WARN $mac — no stage scripts found in $mac_dir" >&2
          fi
        fi
      done
    }

    case "''${1:-help}" in
      list)
        list_machines
        ;;
      status)
        if [ -z "''${2:-}" ]; then
          echo "Usage: netboot-advance status <mac>" >&2
          exit 1
        fi
        show_status "$2"
        ;;
      advance)
        if [ -z "''${2:-}" ]; then
          echo "Usage: netboot-advance advance <mac>" >&2
          exit 1
        fi
        advance_stage "$2"
        ;;
      reset)
        if [ -z "''${2:-}" ]; then
          echo "Usage: netboot-advance reset <mac>" >&2
          exit 1
        fi
        reset_stage "$2"
        ;;
      set)
        if [ -z "''${3:-}" ]; then
          echo "Usage: netboot-advance set <mac> <stage>" >&2
          exit 1
        fi
        set_stage "$2" "$3"
        ;;
      init)
        init_machines
        ;;
      scan)
        scan_leases
        ;;
      help|--help|-h)
        usage
        ;;
      *)
        echo "Unknown command: $1" >&2
        usage
        exit 1
        ;;
    esac
  '';

  # ── Webhook: receives config from discover stage ──
  # Templates with __PLACEHOLDER__ (not ${}) to avoid Nix/bash quoting issues
  diskoTemplate = pkgs.writeText "disko-template.nix" ''
    { ... }: {
      disko.devices.disk.main = {
        type = "disk";
        device = "__DEVICE__";
        content = {
          type = "gpt";
          partitions = {
            esp = {
              size = "1G";
              type = "EF00";
              content = { type = "filesystem"; format = "vfat"; mountpoint = "/boot"; };
            };
            msr = { size = "16M"; type = "MSR"; content = null; };
            windows = {
              size = "__WINDOWS_SIZE__";
              content = { type = "filesystem"; format = "ntfs"; mountpoint = null; };
            };
            nixos = {
              size = "100%";
              content = { type = "filesystem"; format = "ext4"; mountpoint = "/"; };
            };
          };
        };
      };
    }
  '';

  configTemplate = pkgs.writeText "config-template.nix" ''
    { config, pkgs, lib, ... }: {
      system.stateVersion = "25.05";
      networking.hostName = "__HOSTNAME__";
      nixpkgs.hostPlatform = "x86_64-linux";
      boot.loader = {
        efi.canTouchEfiVariables = true;
        grub = {
          enable = true;
          devices = [ "nodev" ];
          efiSupport = true;
          extraEntries = '''
            menuentry "Windows 11" {
              search --set=root --label ESP
              chainloader /EFI/Microsoft/Boot/bootmgfw.efi
            }
          ''';
        };
      };
      services.xserver.enable = true;
      services.xserver.desktopManager.gnome.enable = true;
    }
  '';

  webhookHandler = pkgs.writeShellScriptBin "netboot-webhook" ''
    set -euo pipefail

    PXE_DIR="${cfg.httpRoot}"
    STAGES_DIR="$PXE_DIR/stages"

    read -r request_line
    while IFS= read -r header_line; do
      [ -z "$header_line" ] && break
    done

    # Read the request body
    content_length=$(grep -oi 'Content-Length: *[0-9]*' <<< "$headers" 2>/dev/null | grep -o '[0-9]*' || echo "0")
    body=""
    if [ "$content_length" -gt 0 ]; then
      body=$(head -c "$content_length" /dev/stdin)
    fi

    # Minimal JSON parsing (no jq dependency)
    mac=$(echo "$body" | grep -o '"mac"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"mac"[[:space:]]*:[[:space:]]*"//;s/"//')
    disk=$(echo "$body" | grep -o '"disk"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"disk"[[:space:]]*:[[:space:]]*"//;s/"//')
    hostname=$(echo "$body" | grep -o '"hostname"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"hostname"[[:space:]]*:[[:space:]]*"//;s/"//')
    windows_size=$(echo "$body" | grep -o '"windowsSize"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"windowsSize"[[:space:]]*:[[:space:]]*"//;s/"//')
    windows_size=''${windows_size:-150G}

    if [ -z "$mac" ] || [ -z "$disk" ]; then
      echo -e "HTTP/1.1 400 Bad Request\r\nContent-Type: text/plain\r\n\r\nMissing required fields: mac, disk"
      exit 1
    fi

    CONFIG_DIR="$PXE_DIR/machines/$mac"

    # Generate disko config from template
    mkdir -p "$CONFIG_DIR"
    sed -e "s|__DEVICE__|$disk|g" \
        -e "s|__WINDOWS_SIZE__|$windows_size|g" \
        ${diskoTemplate} > "$CONFIG_DIR/disko.nix"

    # Generate NixOS config from template
    sed -e "s|__HOSTNAME__|$hostname|g" \
        ${configTemplate} > "$CONFIG_DIR/configuration.nix"

    # Create config bundle
    tar czf "$CONFIG_DIR/config.tar.gz" -C "$CONFIG_DIR" disko.nix configuration.nix

    # Auto-advance: move from discover → next stage
    ${netbootAdvance}/bin/netboot-advance advance "$mac" 2>/dev/null || true

    echo -e "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\n\r\nOK"
  '';

in
{
  config = mkIf cfg.enable (mkMerge [
    # Common: both CLI and daemon mode get these tools
    {
      environment.systemPackages = [ netbootAdvance (pkgs.callPackage ../../../packages/netboot-serve { }) ];
    }

    # Daemon mode: persistent systemd services
    (mkIf (cfg.serveMode == "daemon") {
      systemd.sockets.netboot-webhook = {
        description = "Netboot discover webhook socket";
        listenStreams = [ "${cfg.serverAddress}:8888" ];
        socketConfig = { Accept = true; };
        wantedBy = [ "sockets.target" ];
      };

      systemd.services.netboot-webhook = {
        description = "Netboot discover webhook handler";
        after = [ "network.target" "systemd-tmpfiles-setup.service" ];
        requires = [ "network.target" ];
        serviceConfig = {
          ExecStart = "${webhookHandler}/bin/netboot-webhook";
          StandardInput = "socket";
          Type = "simple";
        };
      };

      systemd.services.netboot-init = {
        description = "Initialize netboot per-MAC state symlinks";
        after = [ "network.target" "systemd-tmpfiles-setup.service" ];
        requires = [ "network.target" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = ''
          ${netbootAdvance}/bin/netboot-advance init
        '';
      };
    })
  ]);
}
