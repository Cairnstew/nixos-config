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

## Remote state

Set `backend` to keep state out of the host:

```nix
stack = {
  backend = { kind = "gcs"; bucket = "<bucket>"; prefix = "<stack>"; };
  external_buckets = [ "<bucket>" ];   # required, see below
};
```

`prefix` defaults to `python-tofu/<stack name>`. Two things to know:

- **The bucket must exist before `tofu init`**, so it is bootstrapped
  out-of-band, not declared in the same stack. The credential needs
  `storage.buckets.create` plus `storage.objects.*`; upstream's
  `scripts/bootstrap-org-admin.sh` grants `roles/storage.admin` on the host
  project for exactly this reason (and can be re-run with `--no-key` to add the
  binding to an existing seed account).
- **List it in `external_buckets`.** `external_buckets` are treated as declared
  and are never pruned; without the entry, `prune.sections = ("all",)` includes
  `buckets` and would delete the bucket holding the state.
- **A backend change is a one-time migration.** `apply` runs
  `tofu init -input=false` internally, which cannot migrate state, so switching
  an existing workdir from local to GCS fails until
  `tofu init -migrate-state` has been run once by hand.

Versioning on the bucket (`--enable-versioning`) is what makes a bad apply
recoverable: state objects can be restored from a previous generation.

## Cost guardrails

Two different mechanisms, and only one of them can stop a spend:

| Mechanism | Effect |
|---|---|
| `limits_mode = "error"` | **Enforced before the provider call.** Refuses to plan/apply when the stack measures above the GCP free-tier policy. |
| `billing_budgets.<name>` | **Alert-only.** GCP has no hard spend cap; a budget emails the billing admins at the thresholds and never disables billing. |

```nix
stack = {
  limits_mode = "error";
  billing_budgets.guardrail = {
    billing_account = "<id>";
    display_name = "nixos-config guardrail";
    amount = 1;                       # billing-account currency
    thresholds = [ 0.5 0.9 1.0 ];
    project_filter = "<project number>";
  };
};
```

Limits only bind what can be measured: a resource without an
`estimated_size_gb`/`usage_estimates` entry is `unknown`, and unknown limits do
not block unless `--fail-on-unknown` is passed (`settings.extraArgs`). Creating
a budget needs `billing.budgets.create` on the billing account
(`roles/billing.costsManager` or `roles/billing.admin`) — `roles/billing.user`
is not enough and returns `403 PERMISSION_DENIED`. Billing-account IAM is not
inherited from the organization, so this is the one grant a human must make;
upstream's bootstrap script includes the role, but no workload identity can
self-grant it.

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
