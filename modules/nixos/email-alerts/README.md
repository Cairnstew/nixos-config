# Email Alerts

Centralized email alerting via SMTP (Gmail). Provides a `send-alert` CLI script
that other system services can use to send email notifications.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `my.services.emailAlerts.enable` | `false` | Enable email alerts |
| `my.services.emailAlerts.smtp.host` | `"smtp.gmail.com"` | SMTP server |
| `my.services.emailAlerts.smtp.port` | `587` | SMTP port |
| `my.services.emailAlerts.smtp.user` | `me.email` | SMTP username |
| `my.services.emailAlerts.smtp.from` | `me.email` | From address |
| `my.services.emailAlerts.to` | `[me.email]` | Default recipients |
| `my.services.emailAlerts.secretName` | `"alert-gmail"` | Agenix secret name |

## Usage

```nix
my.services.emailAlerts.enable = true;
```

Other systemd services can send alerts via:

```bash
send-alert -s "System Alert" -b "Something happened on $(hostname)"
send-alert -s "Critical" -b "Disk space low" -t "admin@example.com"
```

## Notes

Uses the `alert-gmail` agenix secret — a Gmail app password. Enable
[2-Step Verification](https://myaccount.google.com/security) on the Google
account, then generate an app password at
https://myaccount.google.com/apppasswords.

The secret is encrypted with the `deployment` key group; ensure it's
available on target hosts.
