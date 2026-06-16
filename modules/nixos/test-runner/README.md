# Test Runner

Centralized test runner that discovers and executes module-level smoke tests and health checks at runtime.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `my.testing.enable` | `false` | Enable the test runner |
| `my.testing.categories` | `["smoke" "health"]` | Test categories to run: `smoke` (`*-smoke-test` services), `health` (`*-health-check` services) |
| `my.testing.failHard` | `false` | Stop on first failure |
| `my.testing.startAtBoot` | `false` | Run automatically at boot |

## Usage

### Manual run
```bash
sudo systemctl start my-test-runner
journalctl -u my-test-runner --no-pager
```

### Build the standalone script (CI/CD)
```bash
nix build .#nixosConfigurations.<host>.config.system.build.my-test-runner
./result/bin/my-test-runner
```

Note: The standalone script requires a running systemd (actual host or VM).

## How it works

At evaluation time, the module scans `config.systemd.services` for all services whose
names end in `-smoke-test` or `-health-check` (based on the selected categories).
It generates a shell script that runs each discovered service via `systemctl restart`
and aggregates pass/fail results.

## Adding a test to your module

Tests follow the conventions in `modules/AGENT.md` §5:
- **L0 (assertions):** Nix evaluation-time checks — always active.
- **L1 (health checks):** A `*-health-check` oneshot service with `RemainAfterExit=true`
  and `wantedBy = ["multi-user.target"]` — runs at boot.
- **L2 (smoke tests):** A `*-smoke-test` oneshot service with no `wantedBy` — run
  manually or triggered by this test runner.

The test runner discovers both L1 and L2 tests automatically — no registration needed.
