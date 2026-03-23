# Tailscale NixOS Module

A NixOS module for Tailscale with agenix secret management, MagicDNS via systemd-resolved, and optional auto-generated SSH config from your tailnet's machine list.

---

## Options

### VPN

| Option | Type | Default | Description |
|---|---|---|---|
| `enable` | `bool` | `false` | Enable the module |
| `authKeySecretFile` | `path \| null` | `null` | agenix-encrypted auth key (tskey-auth-xxx) |
| `tags` | `[string]` | `[]` | Tags to advertise, e.g. `["tag:nixos"]` |
| `exitNode` | `bool` | `false` | Advertise as an exit node |
| `openFirewall` | `bool` | `true` | Open the Tailscale UDP port |

### SSH (`ssh.*`)

| Option | Type | Default | Description |
|---|---|---|---|
| `ssh.enable` | `bool` | `false` | Enable SSH config generation |
| `ssh.user` | `string` | — | Local user whose `~/.ssh/config` is managed |
| `ssh.sshKeySecretFile` | `path` | — | agenix-encrypted SSH private key |
| `ssh.apiKeySecretFile` | `path` | — | agenix-encrypted Tailscale API key (tskey-api-xxx) |
| `ssh.extraHostConfig` | `lines` | `""` | Extra lines appended to every generated Host block |

---

## Setup

### 1. Configure your ACL policy

In the [Tailscale admin console](https://login.tailscale.com/admin/acls), ensure any tags you use are in `tagOwners`:

```json
{
  "tagOwners": {
    "tag:nixos":    ["autogroup:owner"],
    "tag:personal": ["autogroup:owner"]
  }
}
```

### 2. Enable MagicDNS

In the admin console go to **DNS** and enable **MagicDNS**. This gives every machine a stable `<hostname>.ts.net` name that the module wires up via `systemd-resolved`.

### 3. Generate secrets

**Tailscale auth key** — goes to [Settings → Keys](https://login.tailscale.com/admin/settings/keys), create an auth key (tick **Reusable** if shared), encrypt it:

```bash
agenix -e secrets/tailscale-authkey.age
```

**SSH keypair** — create one and distribute the public key to `~/.ssh/authorized_keys` on every machine you want to reach:

```bash
ssh-keygen -t ed25519 -f tailscale_id -C "tailscale"
agenix -e secrets/tailscale-ssh-key.age   # paste contents of tailscale_id
```

**Tailscale API key** — back in [Settings → Keys](https://login.tailscale.com/admin/settings/keys), create an **API key** for the machine-list lookup:

```bash
agenix -e secrets/tailscale-apikey.age
```

### 4. Configure the module

```nix
my.services.tailscale = {
  enable            = true;
  authKeySecretFile = ./secrets/tailscale-authkey.age;
  tags              = [ "tag:nixos" ];

  ssh = {
    enable           = true;
    user             = "seanc";
    sshKeySecretFile = ./secrets/tailscale-ssh-key.age;
    apiKeySecretFile = ./secrets/tailscale-apikey.age;
    # Optional: appended to every Host block
    extraHostConfig  = "ForwardAgent yes";
  };
};
```

### 5. Rebuild

```bash
nixos-rebuild switch
```

The generated section in `~/.ssh/config` will look like:

```
# BEGIN tailscale-managed
Host myserver
  HostName myserver.ts.net
  IdentityFile /run/agenix/tailscale-ssh-key
  IdentitiesOnly yes

Host mylaptop
  HostName mylaptop.ts.net
  IdentityFile /run/agenix/tailscale-ssh-key
  IdentitiesOnly yes

# END tailscale-managed
```

Anything you write outside those markers is left untouched. After switching you can just `ssh myserver`.

---

## Secrets Layout

```
secrets/
  tailscale-authkey.age     # tskey-auth-xxx  — VPN auth key
  tailscale-apikey.age      # tskey-api-xxx   — API key for machine list
  tailscale-ssh-key.age     # SSH private key — shared across all machines
```

All secrets are auto-declared under `age.secrets` by the module.

---

## Troubleshooting

**`tailscaled-autoconnect.service` fails with _"requested tags are invalid or not permitted"_**

The tag is missing from `tagOwners` in your ACL. Add it in the admin console, generate a new auth key, re-encrypt and rebuild.

**MagicDNS names don't resolve**

Ensure MagicDNS is enabled in the admin console, then verify resolved has picked up the config:

```bash
resolvectl status
# Should show 100.100.100.100 as the DNS server for the ts.net domain
```

**SSH config not updating**

The activation script runs at every `nixos-rebuild switch`. If the API key has expired, re-encrypt a fresh one and rebuild. You can also force re-activation manually:

```bash
sudo /nix/var/nix/profiles/system/activate
```

**`ssh <hostname>` still asks for a password**

Make sure `tailscale_id.pub` is in `~/.ssh/authorized_keys` on the target machine and that `sshd` is configured to allow pubkey auth (`PubkeyAuthentication yes`).