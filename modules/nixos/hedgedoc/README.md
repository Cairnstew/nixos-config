# HedgeDoc

Collaborative markdown editor with nginx reverse proxy.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `my.services.hedgedoc.enable` | `false` | Enable HedgeDoc |
| `my.services.hedgedoc.domain` | `"pad.srid.ca"` | Domain |
| `my.services.hedgedoc.port` | `9112` | Local port |
| `my.services.hedgedoc.allowAnonymous` | `false` | Allow anonymous access |

## Usage

```nix
my.services.hedgedoc.enable = true;
```

## Secrets

Requires `secrets/hedgedoc.env.age` with HedgeDoc environment variables.
