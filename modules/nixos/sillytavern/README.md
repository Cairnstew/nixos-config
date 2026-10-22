# SillyTavern

Thin wrapper around the upstream `github:Cairnstew/SillyTavern` flake module.

## Options

This module declares **no** options of its own. Everything lives upstream under
`services.sillytavern-nixos.*`:

| Option | Default | Description |
|--------|---------|-------------|
| `services.sillytavern-nixos.enable` | `false` | Enable the service |
| `services.sillytavern-nixos.config.port` | `8000` | Listen port |
| `services.sillytavern-nixos.config.whitelistMode` | `true` | Restrict access to the host whitelist |
| `services.sillytavern-nixos.users` | `{}` | Accounts to seed (`passwordFile`, `admin`) |
| `services.sillytavern-nixos.settings.common` | `{}` | `settings.json` seeded into every account |
| `services.sillytavern-nixos.presets.common` | `{}` | Named presets (textgen, instruct, context, sysprompt, reasoning, themes…) |
| `services.sillytavern-nixos.files.common` | `{}` | Extra JSON files seeded into the data root |
| `services.sillytavern-nixos.extensions` | `{}` | Third-party UI extensions, pinned by `url` + `rev` |
| `services.sillytavern-nixos.plugins` | `{}` | Server-side plugins, pinned by `url` + `rev` |
| `services.sillytavern-nixos.proxyUpstreams` | `[]` | Reverse-proxy hints for a consumer's proxy |

The namespace is **not** `services.sillytavern` — that belongs to nixpkgs' own
module, which this config does not enable (upstream asserts the two are never
both enabled: they share the unit, the system account and the state directory).

## Usage Example

```nix
services.sillytavern-nixos = {
  enable = true;
  config.port = 8000;

  users.seanc = {
    passwordFile = config.age.secrets.sillytavern-seanc.path;
    admin = true;
  };

  presets.common.textGeneration.Reasoning.json = {
    temp = 1.0;
    top_k = 40;
    include_reasoning = true;
  };
};
```

## Notes

- **Upstream:** the implementation is upstream's; only the proxy wiring, the
  `TRUST_PROXY` env var and the Ollama model pre-pull are local. The fork is
  registered as the `sillytavern` Agent Space
  (`my.programs.opencode.ensemble.spaces`), so implementation changes are made
  with `team_spawn(space="sillytavern", …)` in `/home/seanc/Projects/SillyTavern`
  and the input is re-pinned automatically on a clean shutdown
  (`autoUpdateFlakeInput`); `nix flake update sillytavern` remains the manual
  path.
- **Reverse proxy:** the wrapper registers `my.services.proxy.upstreams.sillytavern`
  at `/sillytavern/`, with the root-relative SPA paths (`/assets/`, `/api/`, …)
  proxied separately.
- **Ollama:** models named by the account's Ollama connection profiles
  (`settings.common.extension_settings.connectionManager.profiles`) are pulled
  before the service starts. A failed pull warns, it does not fail the unit.
- **Health check:** upstream ships `sillytavern-healthcheck.service`
  (`systemctl start sillytavern-healthcheck`).
- **Not carried over from the old local wrapper:** the Similharity Qdrant
  server plugin (it needs npm dependencies a plain git checkout cannot
  provide) and the Resemble.ai TTS provider (it patched SillyTavern's own TTS
  extension JS, which upstream's package owns now). VectFox survives as a
  pinned `extensions` entry. Both are re-addable — upstream's `plugins`
  option takes a git source, and a TTS provider is a small patch against
  `services.sillytavern-nixos.package`.
- **Docs:** `https://github.com/Cairnstew/SillyTavern` — `docs/options.md`,
  `docs/installing.md`, `docs/users.md`.
