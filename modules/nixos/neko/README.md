# Neko — Self-Hosted Remote Browser

Neko is a self-hosted virtual browser that runs in Docker and uses WebRTC to
stream a headful Firefox (or Chromium, etc.) to a browser tab.

## Usage

Enable the module in your host config:

```nix
my.services.neko.enable = true;
```

This registers the service at `/neko/` on the Caddy reverse proxy, accessible
via `https://server.tail685690.ts.net/neko/`.

## Secrets

Two agenix secrets must be provisioned before starting the container:

| Secret | Purpose | Default location |
|--------|---------|-----------------|
| `neko-admin-password` | Admin password (full control) | `/run/agenix/neko-admin-password` |
| `neko-user-password` | User password (view only) | `/run/agenix/neko-user-password` |

Provision them via the existing agenix workflow:

```bash
agenix-manager new neko-admin-password
agenix-manager new neko-user-password
```

Then reference them in your host config:

```nix
my.services.neko = {
  enable = true;
  adminPasswordFile = config.age.secrets."neko-admin-password".path;
  userPasswordFile = config.age.secrets."neko-user-password".path;
};
```

**Password security note:** Passwords are written to `/run/neko/env` (a tmpfs
file, not persisted to disk) by a systemd oneshot service that runs before the
container starts. The container reads this file via Docker's `--env-file` flag.
This avoids storing passwords in the Nix store or making them visible via
`docker inspect`.

## Firewall

The WebRTC UDP port range (default 52000-52100) is **not** opened in the
host firewall by default — `tailscale0` is a trusted interface and Neko is
served over the tailnet. If you need to expose Neko outside the tailnet,
set:

```nix
my.services.neko.openFirewall = true;
```

## GPU Acceleration

Currently configured for CPU-only (`ghcr.io/m1k1o/neko/firefox:latest`).
GPU passthrough (NVIDIA NVENC or Intel/AMD VAAPI) is not yet implemented —
see the runtime/ directory in the upstream repo for NVIDIA and Intel
Dockerfiles.

## Options Reference

| Option | Default | Description |
|--------|---------|-------------|
| `enable` | `false` | Enable Neko |
| `image` | `ghcr.io/m1k1o/neko/firefox:latest` | OCI image |
| `port` | `8080` | HTTP/WS control port |
| `webrtcPortRange.from` | `52000` | WebRTC UDP range start |
| `webrtcPortRange.to` | `52100` | WebRTC UDP range end |
| `natIp` | `100.78.102.28` | NAT1TO1 IP (Tailscale IP) |
| `adminPasswordFile` | `null` | Admin password file path |
| `userPasswordFile` | `null` | User password file path |
| `openFirewall` | `false` | Open UDP ports in firewall |
| `shmSize` | `2gb` | /dev/shm size |
| `desktopScreen` | `1920x1080@30` | Desktop resolution |
| `backend` | `"docker"` | Container backend |
| `network.name` | `"neko-net"` | Docker network |
| `network.alias` | `"neko"` | Network alias |
