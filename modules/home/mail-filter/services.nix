{ config, lib, pkgs, ... }:
let
  cfg = config.my.services.mailFilter;
  secretPath = "/run/agenix/${cfg.secretName}";

  # Run the compiled Sieve script against the synced Maildir. Requires the
  # generated dovecot.conf (maildir layout fs + static userdb) for sieve-filter.
  filterCmd =
    let
      confArg = "-c $HOME/.config/mail-filter/dovecot.conf";
      scriptPath = "$HOME/.config/mail-filter/filter.sieve";
      modeArgs =
        if cfg.filter.dryRun then "-v" else "-e -W -v";
    in
    ''
      set -euo pipefail
      SCRIPT="$HOME/.config/mail-filter/filter.sieve"
      CONF="$HOME/.config/mail-filter/dovecot.conf"
      [ -f "$SCRIPT" ] || { echo "mail-filter: no sieve script (have you run home-manager?)"; exit 0; }
      [ -f "$CONF" ] || { echo "mail-filter: no dovecot.conf"; exit 0; }

      # Compile (writes filter.svbin next to the .sieve; sieve-filter reuses it
      # while it is newer than the source). Pigeonhole 0.5 semantics: no -d.
      sievec ${confArg} "$SCRIPT"

      # Pass the SOURCE script path — 0.5's sieve-filter resolves the compiled
      # filter.svbin itself by basename (passing the .svbin directly makes it
      # try to parse binary as Sieve text).
      exec sieve-filter ${confArg} ${modeArgs} -m ${cfg.filter.sourceMailbox} \
        "${scriptPath}" ${cfg.filter.sourceMailbox} keep
    '';

  filterScript = pkgs.writeShellScript "mail-filter" filterCmd;
in
{
  config = lib.mkIf cfg.enable {
    systemd.user.services.mail-filter = {
      Unit = {
        Description = "Run the Sieve mail filter over the mbsync Maildir";
        After = [ "mbsync.service" ];
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${filterScript}";
      };
    };

    # Run the filter right after every successful mbsync sync.
    services.mbsync.postExec = lib.mkIf cfg.filter.enable "${filterScript}";

    # Don't sync at all when the agenix secret is absent at runtime (stale
    # activation) — skip instead of auth-failing in a loop.
    systemd.user.services.mbsync.serviceConfig.ExecCondition = "${pkgs.coreutils}/bin/test -e ${secretPath}";
  };
}