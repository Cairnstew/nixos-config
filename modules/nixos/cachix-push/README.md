# Cachix Push

Periodically push Nix store paths to a Cachix binary cache.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `my.services.cachix-push.enable` | `false` | Enable push service |
| `my.services.cachix-push.cacheName` | — | Cachix cache name |
| `my.services.cachix-push.tokenFile` | — | Auth token file path |
| `my.services.cachix-push.onCalendar` | `"weekly"` | Push schedule |

## Usage

```nix
my.services.cachix-push = {
  enable = true;
  cacheName = "my-cache";
  tokenFile = config.age.secrets.cache-token.path;
};
```
