# Mail Filter (tag-in-place)

Reads Gmail over IMAP and applies the repo's canonical mail taxonomy
(`flake.config.mail.tags`) as **Gmail labels** via `X-GM-LABELS`.

Nothing is moved, copied, or deleted. Every message stays in `INBOX`; labels
are layered on top, exactly like Gmail's own web UI would do.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `my.services.mailFilter.enable` | `false` | Enable the `mail-tag` user service + timer |
| `my.services.mailFilter.address` | `flake.config.me.email` | Gmail address (IMAP login) |
| `my.services.mailFilter.secretName` | `mcp-better-email-password` | agenix secret holding the app password |
| `my.services.mailFilter.dryRun` | **`true`** | Preview only — never writes labels |
| `my.services.mailFilter.frequency` | `*:0/15` | systemd **calendar** expression for the timer |
| `my.services.mailFilter.limit` | `500` | Only scan the N most recent UIDs (bounds backfill) |
| `my.services.mailFilter.tags` | `flake.config.mail.tags` | Tag → label + matcher definitions |
| `my.services.mailFilter.tagScript` | *(generated, read-only)* | The Python script written to the store |

> There is no `imap.host` option — the host is currently hardcoded to
> `imap.gmail.com` in `services.nix`.

## Usage Example

```nix
# configurations/nixos/desktop/default.nix
my.homeManager.extraConfig.my.services.mailFilter = {
  enable = true;
  # dryRun defaults to true: set to false only after you have reviewed a
  # dry-run output you are happy with.
  dryRun = false;
  limit = 1000;
};
```

## How it works

1. `mail-tag.timer` fires on `frequency` (a systemd calendar expression, e.g.
   `*:0/15`); `mail-tag.service` is `oneshot`. Validate a change with
   `systemd-analyze calendar '<expr>'` — an invalid expression does not fail
   the build, it fails *activation* with `BadUnitSetting`.
2. `ExecCondition = test -e /run/agenix/<secretName>` — the unit is **skipped
   silently** (not failed) when the agenix secret is absent, e.g. on a host
   that does not have this key.
3. The generated script:
   - logs in, `m.select("INBOX")` **read-write** (required for `STORE`),
   - pulls the newest `limit` UIDs from `UID SEARCH ALL`,
   - fetches `UID`, `X-GM-LABELS` and the `From`/`Subject`/`List-Id` headers in
     **one round trip** per message,
   - lowercases each matcher and each header, then applies any tag whose
     matcher list contains a hit,
   - skips labels that already exist on the message (idempotent),
   - in dry-run prints `[dry] UID …: +Label`, otherwise issues
     `UID STORE <uid> +X-GM-LABELS ("Label" …)`.

## Verification done

- `mcp-better-email-password` verified live against `imap.gmail.com:993` and
  `smtp.gmail.com:587`. **`alert-gmail` is dead** — see GOTCHAS.
- Combined `UID X-GM-LABELS BODY.PEEK[HEADER.FIELDS (…)]` fetch, `STORE
  +X-GM-LABELS`, and `UID SEARCH X-GM-LABELS` were all probed against the real
  mailbox and confirmed; a `STORE +X-GM-LABELS` probe round-trip was **reverted
  and verified** back to its original state.
- The generated script passed `ast.parse` and a live `--dry-run`: exit 0, 500
  scanned, 261 would receive labels.

## Manual dry run

```bash
python3 $(nix build --no-link --print-out-paths \
  '.#nixosConfigurations.desktop.config.home-manager.users.seanc.my.services.mailFilter.tagScript') \
  imap.gmail.com <address> /run/agenix/mcp-better-email-password --dry-run
```

Or trigger the built-in smoke test (always `--dry-run`, regardless of
`dryRun`):

```bash
systemctl --user start mail-tag-smoke-test
```

## Notes

- **Safe by default.** `dryRun = true` and `limit = 500` mean the first
  activation changes nothing and can only look at the newest 500 messages.
- **Matchers are case-insensitive substrings** (`m.lower() in h.lower()`), so
  short/broad matchers like `order`, `update`, `sale`, `security`, `notice`,
  `target`, `bank`, `job`, `food` **will over-tag**. That is the documented
  contract of `flake.config.mail.tags`; review a dry-run before disabling
  `dryRun`. Tags with no matchers are skipped entirely (they are accepted for
  compatibility with `flake.config.mail`).
- **Idempotent.** Existing labels are decoded from the fetch meta line and
  re-applied only if missing, so re-running never duplicates a label.
- **Backfill** is bounded by `limit`, not by a separate mode: raise it
  gradually after confirming the first pass looks right.
- Requires `/run/agenix/<secretName>` (owner-readable, `0400`) at runtime.

## Layout

| File | Role |
|------|------|
| `default.nix` | import manifest only — `tag.nix`, `services.nix`, `tests.nix` |
| `tag.nix` | all options + the generated Python script |
| `services.nix` | `mail-tag` user service + timer |
| `tests.nix` | eval-time assertions + `mail-tag-smoke-test` |
| `meta.nix` | module metadata |
