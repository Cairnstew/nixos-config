{ config, lib, pkgs, ... }:
let
  cfg = config.my.services.mailFilter;
  secretPath = "/run/agenix/${cfg.secretName}";
in
{
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.address != "";
        message = "my.services.mailFilter.address must not be empty (set flake.config.me.email or override).";
      }
      {
        assertion = cfg.secretName != "";
        message = "my.services.mailFilter.secretName must not be empty.";
      }
      {
        assertion = cfg.limit > 0;
        message = "my.services.mailFilter.limit must be a positive number of messages to scan.";
      }
      {
        assertion = (lib.filter (t: (t.matchers or [ ]) != [ ] && (t.path or "") == "") (lib.attrValues cfg.tags)) == [ ];
        message = "my.services.mailFilter.tags: every tag with matchers must have a non-empty 'path'.";
      }
      {
        assertion = cfg.tagScript != null;
        message = "my.services.mailFilter.tagScript did not evaluate (is the config block enabled?).";
      }
    ];

    # L2 smoke test — triggers manually:  systemctl --user start mail-tag-smoke-test
    # Always --dry-run regardless of cfg.dryRun, so it can never write labels.
    systemd.user.services.mail-tag-smoke-test = {
      Unit.Description = "Dry-run the Gmail IMAP tagger without changing anything";
      Service = {
        Type = "oneshot";
        ExecStart = "${pkgs.python3}/bin/python3 ${cfg.tagScript} imap.gmail.com ${cfg.address} ${secretPath} --dry-run";
        ExecCondition = "${pkgs.coreutils}/bin/test -e ${secretPath}";
      };
    };
  };
}
