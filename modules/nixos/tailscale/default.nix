{ config, lib, pkgs, ... }:

let
  inherit (lib) mkEnableOption mkOption mkIf mkMerge types;

  cfg = config.my.services.tailscale;
  sec = config.my.secrets;

  apiKeyPath = config.age.secrets.${sec.names.tailscale.apiKey}.path;
  sshKeyPath = config.age.secrets.${sec.names.tailscale.sshKey}.path;

  sshConfigPath =
    if cfg.ssh.sshConfigPath != null
    then cfg.ssh.sshConfigPath
    else "/home/${cfg.ssh.user}/.ssh/config.d/tailscale";

  # ---------------------------------------------------------------------------
  # Wait-for-tailscale helper — a separate derivation so it can be used both
  # in ExecStartPre and independently if needed. Uses `tailscale status` with
  # a generous timeout; exits 0 only when tailscale reports itself as Running.
  # ---------------------------------------------------------------------------
  waitScript = pkgs.writeShellScript "wait-for-tailscale" ''
    set -euo pipefail
    TIMEOUT=120
    ELAPSED=0

    echo "wait-for-tailscale: waiting for tailscaled to be ready..." >&2

    while true; do
      STATUS=$(${pkgs.tailscale}/bin/tailscale status --json 2>/dev/null \
               | ${pkgs.jq}/bin/jq -r '.BackendState // empty' 2>/dev/null || true)

      case "$STATUS" in
        Running)
          echo "wait-for-tailscale: tailscale is Running." >&2
          exit 0
          ;;
        NeedsLogin|NeedsMachineAuth)
          echo "wait-for-tailscale: tailscale state is $STATUS — cannot proceed." >&2
          exit 1
          ;;
      esac

      if [ "$ELAPSED" -ge "$TIMEOUT" ]; then
        echo "wait-for-tailscale: timed out after ${toString cfg.ssh.waitTimeout}s waiting for tailscale." >&2
        exit 1
      fi

      sleep 5
      ELAPSED=$((ELAPSED + 5))
    done
  '';

  # ---------------------------------------------------------------------------
  # Main generator script — only runs once tailscale is confirmed Running.
  # ---------------------------------------------------------------------------
  generatorScript = pkgs.writeShellScript "tailscale-ssh-config" ''
    set -euo pipefail

    SSH_CONFIG="${sshConfigPath}"
    SSH_DIR=$(dirname "$SSH_CONFIG")

    # ── Read API key ──────────────────────────────────────────────────────────
    if ! API_KEY=$(cat "${apiKeyPath}" 2>/dev/null); then
      echo "tailscale-ssh-config: ERROR: cannot read API key at ${apiKeyPath}" >&2
      exit 1
    fi
    if [ -z "$API_KEY" ]; then
      echo "tailscale-ssh-config: ERROR: API key is empty" >&2
      exit 1
    fi

    # ── Fetch device list (3 attempts) ────────────────────────────────────────
    response=""
    for attempt in 1 2 3; do
      if response=$(${pkgs.curl}/bin/curl -sf --max-time 15 \
          -H "Authorization: Bearer $API_KEY" \
          "https://api.tailscale.com/api/v2/tailnet/-/devices" 2>&1); then

        # Validate that we got JSON with a devices key
        if echo "$response" | ${pkgs.jq}/bin/jq -e '.devices' >/dev/null 2>&1; then
          break
        else
          echo "tailscale-ssh-config: attempt $attempt: unexpected API response: $response" >&2
          response=""
        fi
      else
        echo "tailscale-ssh-config: attempt $attempt: curl failed (exit $?)" >&2
      fi
      sleep $((attempt * 5))
    done

    if [ -z "$response" ]; then
      echo "tailscale-ssh-config: ERROR: failed to fetch device list after 3 attempts" >&2
      exit 1
    fi

    # ── Build host blocks ─────────────────────────────────────────────────────
    # .name is the full MagicDNS name (e.g. host.tail1234.ts.net)
    # .hostname is the short name reported by the device — use it as the SSH alias.
    NEW_BLOCK=$(echo "$response" | ${pkgs.jq}/bin/jq -r '
      .devices[]
      | select(
          (.hostname != null and .hostname != "") and
          (.name     != null and .name     != "")
        )
      | "Host " + .hostname
      + "\n  HostName " + .name
      + "\n  IdentityFile ${sshKeyPath}"
      + "\n  IdentitiesOnly yes"
      + "${lib.optionalString (cfg.ssh.extraHostConfig != "")
          "\\n  ${lib.replaceStrings ["\n"] ["\\n  "] cfg.ssh.extraHostConfig}"}"
    ')

    HOST_COUNT=$(echo "$NEW_BLOCK" | grep -c '^Host ' || true)

    if [ "$HOST_COUNT" -eq 0 ]; then
      echo "tailscale-ssh-config: WARNING: API returned devices but none had hostname+name set." >&2
      # Write an empty (but valid) file so SSH doesn't trip on a stale one.
    fi

    # ── Write atomically as the target user ──────────────────────────────────
    mkdir -p "$SSH_DIR"
    chmod 700 "$SSH_DIR"

    TMPFILE=$(mktemp "$SSH_DIR/.tailscale.XXXXXX")
    trap 'rm -f "$TMPFILE"' EXIT

    {
      echo "# BEGIN tailscale-managed — do not edit, regenerated automatically"
      echo "# Last updated: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
      if [ -n "$NEW_BLOCK" ]; then
        echo "$NEW_BLOCK"
      fi
      echo "# END tailscale-managed"
    } > "$TMPFILE"

    chmod 600 "$TMPFILE"
    mv "$TMPFILE" "$SSH_CONFIG"

    echo "tailscale-ssh-config: wrote $HOST_COUNT host(s) to $SSH_CONFIG"
  '';

in
{
  imports = [ ../secrets/default.nix ];

  options.my.services.tailscale = {
    enable       = mkEnableOption "Tailscale mesh VPN";
    openFirewall = mkOption { type = types.bool; default = true;  description = "Open the Tailscale UDP port in the firewall."; };
    exitNode     = mkOption { type = types.bool; default = false; description = "Advertise this machine as a Tailscale exit node."; };

    tags = mkOption {
      type    = types.listOf types.str;
      default = [];
      example = [ "tag:nixos" "tag:personal" ];
      description = "Tailscale ACL tags to advertise for this machine.";
    };

    ssh = {
      enable = mkEnableOption "Auto-generated SSH config fragment for tailnet machines";

      user = mkOption {
        type        = types.str;
        description = "Local user whose SSH config will be managed.";
        example     = "alice";
      };

      publicKeyPath = mkOption {
        type        = types.nullOr types.path;
        default     = null;
        description = "Path to the Tailscale SSH public key to authorise on this host.";
      };

      sshConfigPath = mkOption {
        type        = types.nullOr types.str;
        default     = null;
        description = "Override destination path for the generated fragment. Defaults to ~/.ssh/config.d/tailscale.";
      };

      extraHostConfig = mkOption {
        type        = types.lines;
        default     = "";
        description = "Extra lines appended inside every generated Host block (e.g. 'ForwardAgent yes').";
        example     = "ForwardAgent yes\nServerAliveInterval 60";
      };

      refreshInterval = mkOption {
        type        = types.str;
        default     = "1h";
        description = "How often to refresh the SSH config from the Tailscale API (systemd OnUnitActiveSec interval).";
        example     = "30min";
      };

      waitTimeout = mkOption {
        type        = types.int;
        default     = 120;
        description = "Seconds to wait for tailscale to reach Running state before giving up.";
      };
    };
  };

  config = mkIf cfg.enable (mkMerge [

    # ── Core VPN ──────────────────────────────────────────────────────────────
    {
      services.tailscale = {
        enable       = true;
        openFirewall = cfg.openFirewall;
        authKeyFile  = mkIf sec.enable
          config.age.secrets.${sec.names.tailscale.authKey}.path;
        extraUpFlags =
          [ "--accept-dns=true" ]
          ++ lib.optional (cfg.tags   != []) "--advertise-tags=${lib.concatStringsSep "," cfg.tags}"
          ++ lib.optional  cfg.exitNode       "--advertise-exit-node";
      };

      networking.firewall.trustedInterfaces = [ "tailscale0" ];
      networking.networkmanager.dns         = "systemd-resolved";
      environment.etc."resolv.conf".source  = lib.mkForce "/run/systemd/resolve/stub-resolv.conf";
      services.resolved.enable              = true;
    }

    # ── SSH config generation ──────────────────────────────────────────────────
    (mkIf (cfg.ssh.enable && sec.enable) {

      assertions = [
        {
          assertion = sec.tailscale.sshKey != null;
          message   = "my.services.tailscale.ssh.enable requires my.secrets.tailscale.sshKey to be set.";
        }
        {
          assertion = sec.tailscale.apiKey != null;
          message   = "my.services.tailscale.ssh.enable requires my.secrets.tailscale.apiKey to be set.";
        }
      ];

      age.secrets.${sec.names.tailscale.sshKey}.owner = cfg.ssh.user;

      users.users.${cfg.ssh.user}.openssh.authorizedKeys.keyFiles =
        lib.optional (cfg.ssh.publicKeyPath != null) cfg.ssh.publicKeyPath;

      home-manager.users.${cfg.ssh.user}.my.services.ssh = {
        enable   = true;
        includes = [ "config.d/tailscale" ];
      };

      # ── One-shot service ────────────────────────────────────────────────────
      # Does NOT restart on failure — if tailscale isn't Running or the API
      # key is wrong, restarting in a loop won't help. The timer will retry
      # after refreshInterval anyway. Set StartLimitBurst=0 to disable the
      # systemd-level restart limit error spam.
      systemd.services.tailscale-ssh-config = {
        description = "Generate SSH config from Tailscale API";

        # tailscaled must be running before we even try. network-online ensures
        # we have a route to api.tailscale.com.
        after  = [ "network-online.target" "tailscaled.service" ];
        wants  = [ "network-online.target" ];
        # Hard dependency: if tailscaled isn't active, don't start at all.
        requires = [ "tailscaled.service" ];

        # Do NOT add to multi-user.target — the timer owns scheduling.
        # Removing wantedBy here means the oneshot only runs via the timer
        # (or manual systemctl start). This eliminates the boot race entirely.

        serviceConfig = {
          Type = "oneshot";
          User = cfg.ssh.user;

          # ExecStartPre blocks until tailscale is Running (or times out and
          # fails — which aborts ExecStart cleanly, no restart loop).
          ExecStartPre = waitScript;
          ExecStart    = generatorScript;

          # Never auto-restart a oneshot; let the timer decide when to retry.
          Restart    = "no";

          # Prevent systemd from rate-limiting manual retries.
          StartLimitBurst = 0;
        };
      };

      # ── Timer ───────────────────────────────────────────────────────────────
      # OnBootSec fires once after boot (giving tailscale time to settle).
      # OnUnitActiveSec then fires every refreshInterval thereafter.
      # Persistent=true catches up if the machine was suspended/off.
      systemd.timers.tailscale-ssh-config = {
        description = "Periodically refresh Tailscale SSH config";
        wantedBy    = [ "timers.target" ];
        timerConfig = {
          # Delay first run so tailscale has a chance to authenticate on a
          # fresh boot — the wait script adds its own check, but this keeps
          # the timer log noise down on machines that need auth interaction.
          OnBootSec          = "2min";
          OnUnitActiveSec    = cfg.ssh.refreshInterval;
          RandomizedDelaySec = "60s";
          Persistent         = true;
          Unit               = "tailscale-ssh-config.service";
        };
      };
    })
  ]);
}
