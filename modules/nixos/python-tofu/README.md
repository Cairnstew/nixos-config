# python-tofu

Thin wrapper around the upstream flake input
[`github:Cairnstew/python-tofu`](https://github.com/Cairnstew/python-tofu) — a
typed Python DSL and CLI wrapper that renders HCL and drives
`tofu plan/apply/destroy` for GCP infrastructure.

The upstream `nixosModules.default` (pinned in `flake.lock`) owns the whole
implementation: the `python-tofu.service` oneshot, per-subcommand argv routing,
build-time stack evaluation, sandboxing, `restartTriggers` and the plugin
cache. This module adds only the repo-local glue.

## Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `my.services.python-tofu.enable` | bool | `false` | Enables `services.python-tofu` and the credential wiring |
| `my.services.python-tofu.stack` | attrs or null | `null` | Nix-declared stack (upstream `nix/stack.nix` option tree) |
| `my.services.python-tofu.stackFile` | path or null | `null` | Nix module declaring the stack (for `imports`/`mkMerge`) |
| `my.services.python-tofu.credentialsFile` | str or null | `/run/agenix/gcloud-auth` | Exported as `GOOGLE_APPLICATION_CREDENTIALS`; `null` = ADC |
| `my.services.python-tofu.applyOnRebuild` | bool | `false` | Sets `settings.command = "apply"` + `autoApprove = true` |

Everything else stays on the upstream namespace — `services.python-tofu.*`
(`settings.command`, `settings.workdir`, `settings.limits`, `schedule`,
`environmentFile`, …). It is intentionally **not** re-exported under `my.*`:
duplicating the upstream surface would drift on every input update. See the
upstream [module reference](https://github.com/Cairnstew/python-tofu/blob/main/docs/reference/module.md).

## Usage

Render only (writes HCL, never touches cloud state):

```nix
my.services.python-tofu = {
  enable = true;
  stack = {
    provider = {
      project = "my-project";
      region = "europe-west1";
    };
    buckets.artifacts = {
      project = "my-project";
      location = "EU";
    };
  };
};
```

Reconcile the stack on every rebuild that changes it:

```nix
my.services.python-tofu = {
  enable = true;
  stackFile = ./infra.nix;          # a Nix module using the stack option tree
  applyOnRebuild = true;            # apply + --auto-approve
};
```

The stack is evaluated **at build time** into JSON, so the unit needs neither
network nor a `nix` binary at activation. `applyOnRebuild` relies on upstream
`restartTriggers`, so a `nixos-rebuild switch` re-runs the oneshot whenever the
evaluated stack or toolchain changes. Do not also override
`services.python-tofu.settings.command` while `applyOnRebuild = true` — both are
plain definitions and Nix will report a conflict.

Scheduled drift checks (upstream surface, `my.*` untouched):

```nix
services.python-tofu = {
  schedule = "daily";
  settings = {
    command = "plan";
    extraArgs = [ "--exit-code" ];
  };
};
```

## Credentials

The default `credentialsFile` is `/run/agenix/gcloud-auth`, the repo's
service-account key (`modules/nixos/secrets/secrets-manifest.json`). Following
AGENTS.md §6.4, an `/run/agenix/<name>` path is exported **only when that
secret is declared for the host**; otherwise the variable is left unset and the
CLI falls back to Application Default Credentials. Non-agenix paths (sops,
`systemd.credentials`) are passed through as written.

For secret *values* rather than a file path, use upstream
`services.python-tofu.environmentFile` — never `environment`, which is
world-readable store data.

## Pruning

`prune.enabled = true` makes the **provider project** authoritative. Prune only
inspects `stack.provider.project` (upstream `prune.py`), so a bootstrap stack
that declares a *different* project cannot prune safely — point the stack at
the project it should own. `sections` defaults to `("all",)`; `projects` is
never implied by `all` and must be named explicitly (and only deletes projects
carrying `goog-terraform-provisioned`).

Prune's `subscriptions`/`topics` discovery calls the Pub/Sub API. If `apis`
pruning would otherwise disable `pubsub.googleapis.com`, declare it so it stays
enabled and protected:

```nix
stack.apis.pubsub = {
  project = "<provider-project>";
  service = "pubsub.googleapis.com";
};
```

Without that, the next prune fails with `403 … pubsub.googleapis.com/v1/…`.

## Tests

`tests.nix` carries L0 assertions only: the systemd unit is declared upstream,
so there is no local L1/L2 probe to add. Upstream also ships its own
evaluation checks and a `module-vm` NixOS test.

## Upstream

Implementation changes belong in the upstream repo, not here:

```bash
cd ~/Projects/python-tofu      # or wherever it is checked out
# edit, then
nix flake lock --update-input python-tofu   # in this repo
```

See `meta.nix` (`upstream.mode = "wrapped"`) and `modules/AGENT.md` §4.2.
