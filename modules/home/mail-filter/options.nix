# Option declarations for my.services.mailFilter.
# Split out of tag.nix for module-layout conformance (M2/M3): options live in
# this sibling file (imported from ./default.nix), the tagger config stays in
# tag.nix. `email` is re-derived here (not shared) because only the option
# defaults use it.
{ lib, flake, ... }:
let
  inherit (lib) mkEnableOption mkOption types;
  me = flake.config.me or { };
  email = me.email or "";
in
{
  options.my.services.mailFilter = {
    enable = mkEnableOption "Gmail IMAP label tagging based on flake.config.mail.tags";

    address = mkOption {
      type = types.str;
      default = email;
      description = "Gmail address (also the IMAP login).";
    };

    secretName = mkOption {
      type = types.str;
      default = "mcp-better-email-password";
      description = "Agenix secret holding the Gmail app password (decrypted at /run/agenix/<name>).";
    };

    dryRun = mkOption {
      type = types.bool;
      default = true;
      description = "Preview which tags would be applied without actually writing them (safe default).";
    };

    frequency = mkOption {
      type = types.str;
      # Must be a systemd *calendar* expression, not a duration. "15min" is a
      # valid OnActiveSec value but OnCalendar= rejects it, which made the
      # timer "lack value setting", so systemd refused to start it and every
      # home-manager activation died on mail-tag.timer (exit 4 from
      # switch-to-configuration). Verify any change with
      # `systemd-analyze calendar '<expr>'`.
      default = "*:0/15";
      description = ''
        systemd calendar expression for the tagging timer (see
        systemd.time(7)). Calendar syntax, NOT a duration: `*:0/15`
        (every 15 min), `minutely`, `hourly`, `daily`. A bare `15min` is
        invalid here — `systemd-analyze calendar '15min'` fails and the
        timer refuses to start.
      '';
    };

    limit = mkOption {
      type = types.int;
      default = 500;
      description = "Only scan the N most recent messages by UID (bounds the first-run backfill).";
    };

    tags = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          path = mkOption {
            type = types.str;
            description = "Gmail label applied when a matcher hits (e.g. 'Security/1Password').";
          };
          description = mkOption {
            type = types.str;
            default = "";
            description = "Human-readable description (used as a comment in the generated script).";
          };
          matchers = mkOption {
            type = types.listOf types.str;
            default = [ ];
            description = "Case-insensitive substrings matched against From/Subject/List-Id headers.";
          };
          aliases = mkOption {
            type = types.listOf types.str;
            default = [ ];
            description = "Accepted for compatibility with flake.config.mail (unused by tagger).";
          };
        };
      });
      default = (flake.config.mail or { }).tags or { };
      description = "Tag definitions — one Gmail label per attr. Defaults to the canonical taxonomy in flake.config.mail.tags.";
    };

    tagScript = mkOption {
      type = types.path;
      internal = true;
      readOnly = true;
    };
  };
}
