{ config, lib, pkgs, ... }:
let
  cfg = config.my.services.mailFilter;
  secretPath = "/run/agenix/${cfg.secretName}";
  dryFlag = lib.optionalString cfg.dryRun "--dry-run";
in
{
  config = lib.mkIf cfg.enable {
    # ── tagging service + timer ────────────────────────────────────────────────
    # Self-contained: reads Gmail over IMAP, applies X-GM-LABELS in place.
    # Nothing is moved, deleted, or copied locally — no mbsync dependency.
    systemd.user.services.mail-tag = {
      Unit = {
        Description = "Apply Gmail IMAP labels based on mail.tags taxonomy";
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${pkgs.python3}/bin/python3 ${cfg.tagScript} imap.gmail.com ${cfg.address} ${secretPath} ${dryFlag}";
        ExecCondition = "${pkgs.coreutils}/bin/test -e ${secretPath}";
      };
    };

    systemd.user.timers.mail-tag = {
      Unit.Description = "Periodic Gmail label tagger";
      Timer = {
        OnCalendar = cfg.frequency;
        Persistent = true;
      };
      Install.WantedBy = [ "timers.target" ];
    };
  };
}
