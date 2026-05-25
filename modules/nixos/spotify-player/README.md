# spotify-player

Terminal Spotify client with streaming, Spotify Connect, full feature parity.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `my.programs.spotify.enable` | `false` | Enable spotify-player |
| `my.programs.spotify.clientIdFile` | `null` | Path to file with Spotify API client ID (auto-set from agenix) |

## Usage

```nix
my.programs.spotify.enable = true;
```

## Authentication

1. Create a Spotify App at https://developer.spotify.com/dashboard
2. Encrypt the Client ID as an agenix secret:
   ```
   agenix -e secrets/entertainment/spotify-token.age
   ```
3. The module auto-wires `client_id_command` in app.toml when the secret exists
4. Run `spotify_player authenticate` once to complete OAuth

## Notes

- Requires a Spotify Premium account for streaming
- Exposes UDP 5353 for Spotify Connect (mDNS) discovery
- Client ID defaults to ncspot's if no agenix secret is configured
