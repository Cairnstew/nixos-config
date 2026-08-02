# Cloud Infrastructure

Declare cloud infrastructure — VMs, containers, services on **GCP** and **AWS** —
alongside NixOS hosts in the same flake.

## Approach

Two-stage, via **terranix → OpenTofu** for provisioning and **nixos-anywhere /
colmena** for the OS configuration:

```
┌── STAGE 1: PROVISION (this directory) ──┐   ┌── STAGE 2: CONFIGURE ────────────┐
│ nix run .#gcp / .#aws                   │   │ nixos-anywhere --flake .#<host>  │
│  • VPC, subnet, NAT, firewalls, IAM     │   │   (kexec + disko bootstrap)      │
│  • GPU MIG / EC2 instance               │   │ colmena / nixos-rebuild         │
│  • storage buckets / key pairs          │   │   (push full NixOS config)       │
│  • outputs: IP / hostname ──────────────┼──▶│ agenix decrypts secrets on-host  │
└─────────────────────────────────────────┘   └──────────────────────────────────┘
```

The infrastructure configs are **terranix modules** (Nix → `config.tf.json`), not
NixOS modules. They live here in `cloud/`, wired up by
`modules/flake-parts/cloud.nix` (which imports the official terranix flakeModule).

## Usage

```bash
# GCP
nix run .#gcp -- plan          # or nix run .#gcp.plan
nix run .#gcp -- apply
nix run .#gcp -- destroy

# AWS
nix run .#aws -- plan
nix run .#aws -- apply
nix run .#aws -- destroy

# Inspect the generated Terraform config
nix run .#tf-show-config       # pretty JSON via jq

# Legacy aliases (forward to the gcp config)
nix run .#tf -- plan
nix run .#tf -- apply
```

State is persisted per config in `~/.local/share/terraform/nixos-infra/<name>`
(no remote backend yet — see [State](#state)).

## Configurations

| Directory | Provider | Provisions |
|---|---|---|
| `cloud/gcp/` | Google Cloud | VPC, Cloud NAT, firewalls, GCS model-cache bucket, service account, **NixOS** GPU spot MIG |
| `cloud/aws/` | AWS | VPC, internet gateway, key pair, security group, **NixOS** EC2 instance |

### GCP (`.#gcp`)

Boots a pre-baked NixOS GCE image (family `nixos-25.05`, from the public
`nixos-cloud-images` project) on a preemptible GPU instance. No startup-script
curl-installs, no secrets in instance metadata — the full NixOS configuration is
pushed in stage 2.

Variables (set via `TF_VAR_*` by the wrapper, from agenix secrets when present):

| Variable | Source |
|---|---|
| `gcp_credentials_file` | `/run/agenix/gcloud-auth` |
| `project` | `my.cloud.gcp.project`, else auto-read from the SA JSON |
| `tailscale_auth_key` | `/run/agenix/tailscale-authkey` |
| `ssh_pub_key` | `/run/agenix/aws-ssh-pub-key` |
| `region`, `gpu_type`, `machine_type`, `image_family` | defaults, overridable |

### AWS (`.#aws`)

Provisions a VPC and a `t3.medium` NixOS EC2 instance (AMI auto-fetched from
NixOS's official AMI owner). The `nixos-cloud` key pair is imported from the
`aws-ssh-pub-key` secret.

## Stage 2: deploying NixOS onto provisioned hosts

Once stage 1 outputs an address (see `terraform output public_ip` for AWS),
bootstrap the NixOS config:

```bash
# One-time install (kexec + disko):
nixos-anywhere --flake .#<host> root@<public-ip>

# Ongoing deploys:
colmena apply            # or: nixos-rebuild switch --flake .#<host> --target-host root@<host>
```

The repo already ships `my.nixosAnywhereDeploy.hosts.*` options
(`modules/flake-parts/nixos-anywhere-deploy/`) and agenix secrets
(`aws-cloud`, `aws-ssh-key`, `gcloud-auth`, …) for this.

## Secrets

Credentials are **not** committed. They flow from agenix secrets into `TF_VAR_*`
environment variables via the wrapper's `prefixText` (guarded with `-r` checks so
machines/CI without secrets still evaluate).

> ⚠️ **Known stale secrets:** the `.age` files under
> `modules/nixos/secrets/` (`aws-cloud.age`, `gcloud-auth.age`, `aws-ssh-key.age`,
> …) could not be decrypted with the current host keys (the hosts were likely
> rekeyed since encryption). Regenerate them before `apply`:
>
> ```bash
> nix develop .#secrets
> agenix-manager edit aws-cloud
> agenix-manager edit gcloud-auth
> ```

## State

Terraform state currently lives locally per config. For shared/team use, add a
remote backend to each config (GCS `backend "gcs"` / S3 `backend "s3"` +
DynamoDB lock) via the terranix `terraform.backend` block. Never commit `.tfstate`.

## Gotchas

- Terranix shares `${}` with Terraform: use `lib.tf.ref "var.foo"` / `lib.tf.file`
  instead of manual `\${}` escaping.
- Pin `required_providers` and regenerate the lockfile deliberately
  (`tofu init -upgrade`); do not rely on cached lockfiles.
- Only pass known-at-plan-time values into NixOS config; computed values (e.g. an
  instance IP) cannot feed Nix evaluation — use outputs + stage-2 tools instead.
- Pick one deployment model per host: provision-only (stage-2 tool owns the OS)
  vs nixos-anywhere `all-in-one` (Terraform owns updates). Don't mix.
