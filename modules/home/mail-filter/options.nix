{ config, lib, flake, ... }:
let
  inherit (lib) mkEnableOption mkOption types;
  cfg = config.my.services.mailFilter;
  me = flake.config.me or { };
  email = me.email or "";
in
{
  options.my.services.mailFilter = {
    enable = mkEnableOption "Sieve-based IMAP mail filtering (mbsync sync + pigeonhole sieve-filter)";

    account = mkOption {
      type = types.str;
      default = "gmail";
      description = "The accounts.email.accounts.<name> key this module creates and manages.";
    };

    address = mkOption {
      type = types.str;
      default = email;
      description = "E-mail address (also the IMAP user name for Gmail).";
    };

    userName = mkOption {
      type = types.str;
      default = email;
      description = "IMAP user name. Defaults to the identity e-mail.";
    };

    imap = {
      host = mkOption {
        type = types.str;
        default = "imap.gmail.com";
        description = "IMAP server hostname.";
      };
      port = mkOption {
        type = types.port;
        default = 993;
        description = "IMAP server port (implicit TLS).";
      };
    };

    secretName = mkOption {
      type = types.str;
      default = "mcp-better-email-password";
      description = ''
        agenix secret holding the Gmail app password. Default is the live,
        IMAP-verified app password used by the better-email MCP
        (mcp-better-email-password); override for per-account passwords.
        Decrypted at /run/agenix/<name>.
      '';
    };

    passwordCommand = mkOption {
      type = types.str;
      default = "cat /run/agenix/${cfg.secretName} | tr -d '[:space:]'";
      description = "Command printing the IMAP password to stdout (used as mbsync PassCmd).";
    };

    maildir = mkOption {
      type = types.str;
      default = "~/.mail/gmail";
      description = "Local Maildir root synced by mbsync (mbsync expands ~).";
    };

    sync = {
      frequency = mkOption {
        type = types.str;
        default = "*:0/5";
        description = "systemd OnCalendar value for the mbsync timer (see systemd.time(7)).";
      };
      patterns = mkOption {
        type = types.listOf types.str;
        default = [ "*" "![Gmail]*" "[Gmail]/Sent Mail" "[Gmail]/Starred" "[Gmail]/All Mail" ];
        description = "mbsync channel patterns — ArchWiki Gmail set: everything except the [Gmail] internals we ignore (Trash/Spam/Drafts/Important).";
      };
    };

    filter = {
      enable = mkEnableOption "Sieve filtering after each successful mbsync sync (sieve-filter)" // {
        default = true;
      };

      sourceMailbox = mkOption {
        type = types.str;
        default = "INBOX";
        description = "Mailbox the Sieve script is applied to.";
      };

      dryRun = mkOption {
        type = types.bool;
        default = false;
        description = "Run sieve-filter in simulation mode (prints what would happen, changes nothing).";
      };

      extraSieve = mkOption {
        type = types.lines;
        default = "";
        description = "Raw Sieve appended after the generated rules (e.g. a catch-all fileinto).";
      };
    };

    tags = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          path = mkOption {
            type = types.str;
            description = "Destination mailbox/label path, e.g. 'Security/1Password'.";
          };
          description = mkOption {
            type = types.str;
            default = "";
            description = "Human-readable description (used as a comment).";
          };
          matchers = mkOption {
            type = types.listOf types.str;
            default = [ ];
            description = "Substrings matched (case-insensitive) against From/Subject/List-Id; first match wins.";
          };
          aliases = mkOption {
            type = types.listOf types.str;
            default = [ ];
            description = "Accepted for compatibility with flake.config.mail (unused by script generation).";
          };
        };
      });
      default = (flake.config.mail or { }).tags or { };
      description = ''
        Sieve rules, one per tag. Defaults to the repo's canonical taxonomy
        flake.config.mail.tags (config.nix) so filtering follows the same
        folders Thunderbird/Gmail already use.
      '';
      example = lib.literalExpression ''
        {
          "Security/1Password" = {
            path = "Security/1Password";
            matchers = [ "1password" "hello@1password.com" ];
          };
        }
      '';
    };
  };
}