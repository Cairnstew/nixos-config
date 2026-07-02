# Boot Alerting

Emergency mode email alerting and previous-boot failure detection.

## Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `my.services.bootAlerting.enable` | bool | false | Enable emergency mode alerting and previous-boot failure detection |
| `my.services.bootAlerting.emergencyHook.enable` | bool | true | Inject email sending into emergency.service ExecStartPost |
| `my.services.bootAlerting.emergencyHook.networkTimeout` | int | 10 | Seconds to wait for network in emergency mode |
| `my.services.bootAlerting.detectPreviousBoot` | bool | true | Check on clean boot if previous boot activated emergency.target |
| `my.services.bootAlerting.stateDir` | str | "/var/lib/boot-alerting" | State directory for emergency flag file |
| `my.services.bootAlerting.emailTo` | str | flake.config.me.email | Email address for boot-failure alerts |

## Usage

```nix
my.services.bootAlerting = {
  enable = true;
  emailTo = "admin@example.com";
};
```

## Dependencies

- **agenix secret**: `mcp-better-email-password` at `/run/agenix/mcp-better-email-password`
- **Packages**: msmtp, systemd, coreutils, iproute2, gawk

## Notes

- Email is sent via Gmail SMTP (smtp.gmail.com:587) using an app password.
- Network is started on a best-effort basis in emergency mode (not guaranteed).
- The emergency hook adds ExecStartPost to the existing emergency.service.
- On next clean boot after an emergency, a detailed failure report is sent and the flag is consumed.
