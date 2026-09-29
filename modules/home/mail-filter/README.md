# Mail Filter

Sieve-based IMAP mail organization: mbsync pulls Gmail into a local Maildir,
then pigeonhole's `sieve-filter` applies a Sieve script generated from the
repo's canonical mail taxonomy (`flake.config.mail.tags`) to move matching
mail into label folders. Thunderbird/Gmail keep using the same folders.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `my.services.mailFilter.enable` | `false` | Enable mbsync sync + sieve-filter |
| `my.services.mailFilter.account` | `"gmail"` | `accounts.email.accounts.<name>` key |
| `my.services.mailFilter.address` | `me.email` | E-mail / IMAP user name |
| `my.services.mailFilter.imap.host` | `imap.gmail.com` | IMAP server |
| `my.services.mailFilter.secretName` | `mcp-better-email-password` | agenix secret with the Gmail app password |
| `my.services.mailFilter.maildir` | `~/.mail/gmail` | Local Maildir root |
| `my.services.mailFilter.sync.frequency` | `*:0/5` | systemd OnCalendar for mbsync |
| `my.services.mailFilter.filter.sourceMailbox` | `INBOX` | Mailbox the Sieve script is applied to |
| `my.services.mailFilter.filter.dryRun` | `false` | Run sieve-filter in simulation mode (no changes) |
| `my.services.mailFilter.filter.extraSieve` | `""` | Raw Sieve appended after generated rules |
| `my.services.mailFilter.tags` | `flake.config.mail.tags` | Sieve rules (path + matchers per tag) |

## Usage Example

```nix
# configurations/nixos/desktop/default.nix
my.homeManager.extraConfig.my.services.mailFilter = {
  enable = true;
  # password comes from /run/agenix/mcp-better-email-password at runtime
};
```

## How it works

1. `accounts.email.accounts.<account>` + `programs.mbsync` generate
   `~/.mbsyncrc` (IMAP Store → Maildir Store, `SubFolders Verbatim`, ArchWiki
   Gmail patterns). The user timer `services.mbsync` syncs every 5 minutes.
2. On each successful sync, `services.mbsync.postExec` runs `mail-filter`:
   `sievec` compiles the generated `~/.config/mail-filter/filter.sieve`, then
   `sieve-filter -e -W -m INBOX filter.svbin INBOX keep` moves matches.
   `keep` as discard-action means **non-matching mail is never lost**; for
   Gmail, moves just apply labels (everything stays in All Mail).
3. The filter uses the minimal `~/.config/mail-filter/dovecot.conf`
   (maildir layout `fs` + static userdb) that matches mbsync's on-disk layout.

## Notes

- **Gmail app password**: the default secret `mcp-better-email-password` was
  verified against `imap.gmail.com:993` (and SMTP). `alert-gmail` is **not**
  valid (dead app password — see GOTCHAS). `mcp-better-email-password` is
  owner-owned (`0400`) so the user-level timer can read it.
- **Pigeonhole pin**: `pkgs.dovecot_pigeonhole_0_5` (Dovecot 2.3 pair) with the
  classic config syntax — the 2.4 pigeonhole in nixpkgs cannot register its
  `sieve` settings struct for the CLI tools (`sievec`/`sieve-filter` fail
  config parse). See GOTCHAS.
- **Layout**: the maildir root IS the INBOX (Dovecot `LAYOUT=fs` and the mbsync
  `Inbox` override agree), so `cur/new/tmp` live at the root and label folders
  like `Security/1Password` are subdirectories — matching `SubFolders Verbatim`.
- **Safe by construction**: `sieve-filter` only moves messages that match; the
  discard-action defaults to `keep`. First run is a good time to also run
  `systemctl --user start mail-filter-smoke-test` (compile + simulation).
- **Backfill**: because `sieve-filter` acts on mail already in the Maildir, the
  first sync + filter pass organises existing INBOX mail too ("whatever is
  safer" — no deletions happen).
- **`[Gmail]` internals** (Spam/Trash/Drafts/Important) are excluded from the
  initial sync; Sent/Starred/All Mail are kept read-only via `Patterns`.
- Requires the agenix secret `/run/agenix/<secretName>` at runtime; the mbsync
  unit skips when it is absent (`ExecCondition`).