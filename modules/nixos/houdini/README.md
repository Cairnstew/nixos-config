# Houdini

SideFX Houdini — 3D animation, visual effects, and procedural generation software.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `my.programs.houdini.enable` | `false` | Enable Houdini |
| `my.programs.houdini.package` | `pkgs.houdini` | Houdini package to use |
| `my.programs.houdini.licenseServer` | `null` | Remote license server (`host:port`, mutually exclusive with `localLicenseServer`) |
| `my.programs.houdini.localLicenseServer.enable` | `false` | Run `sesinetd` local license server daemon (listens on port 1715) |
| `my.programs.houdini.redeemNonCommercial.enable` | `false` | Auto-renew Apprentice (NC) licenses via SideFX License API |
| `my.programs.houdini.redeemNonCommercial.serverCode` | *(required)* | Server code from `sesictrl print-server` |
| `my.programs.houdini.redeemNonCommercial.serverName` | `networking.hostName` | Server name sent to the License API |
| `my.programs.houdini.redeemNonCommercial.version` | auto-detected | Houdini `major.minor` version for license generation |
| `my.programs.houdini.redeemNonCommercial.products` | `["HOUDINI-NC" "RENDER-NC"]` | Non-commercial products to license |
| `my.programs.houdini.extraEnv` | `{}` | Extra environment variables |

## Usage Examples

### Basic Installation

```nix
my.programs.houdini.enable = true;
```

### With Remote License Server

```nix
my.programs.houdini = {
  enable = true;
  licenseServer = "license-server.local:1715";
};
```

### Apprentice with Auto-Licensing (recommended for non-commercial use)

Requires a SideFX OAuth application (free, created at
<https://www.sidefx.com/oauth2/applications/>). Store `CLIENT_ID` and
`CLIENT_SECRET` in the `sidefx-app` agenix secret
(`modules/nixos/secrets/sidefx-app.age`), then:

```nix
{ flake, ... }: {
  imports = [ flake.inputs.self.nixosModules.common ];

  my.programs.houdini.enable = true;
  my.programs.houdini.package =
    flake.inputs.houdini-nix.packages.x86_64-linux.houdini-22_0_368;

  my.programs.houdini.redeemNonCommercial = {
    enable = true;
    serverCode = "12345678";  # ← from `sudo sesictrl print-server` after first boot
  };
};
```

The module automatically:
1. Starts the local `sesinetd` license daemon (DynamicUser, hardened service)
2. Redeems Apprentice (NC) license keys from SideFX on first boot
3. Renews them daily via `OnCalendar=daily` timer (29× margin over the 30-day expiry)

### With houdini-nix (newer versions than nixpkgs)

The [houdini-nix](https://github.com/permahorse/houdini-nix) flake provides
builds newer than `pkgs.houdini`. The repo already has it as the
`houdini-nix` flake input. Point `package` at a version output:

```nix
my.programs.houdini.enable = true;
my.programs.houdini.package =
  flake.inputs.houdini-nix.packages.x86_64-linux.houdini-22_0_368;
```

Available version suffixes are listed in the upstream README
(e.g. `houdini-21_0_559`, `houdini-22_0_368`). Each build pins an exact
installer tarball hash — see "Manual installer download" below.

## Initial Setup for Apprentice Auto-Licensing

After deploying the config for the first time:

1. **Start sesinetd** — the `houdini-sesinetd.service` starts automatically on boot.
   Check it's running: `systemctl status houdini-sesinetd`.

2. **Get the server code** — run as root:

   ```bash
   sesictrl print-server
   ```

   This prints `server_name` and `server_code`. Copy the code and add it
   as `my.programs.houdini.redeemNonCommercial.serverCode` in your host config,
   then rebuild. This is a one-time step — the code only changes on reinstall.

3. **Verify licenses** — check that `houdini-license-redeem.service` ran
   successfully:

   ```bash
   journalctl -u houdini-license-redeem.service
   sesictrl print-status
   ```

   You should see `Houdini-Master-NonCommercial` and `Houdini-Render-NonCommercial`
   in the license list.

## Manual Installer Download (REQUIRED)

SideFX does not allow automated downloads, so **no Houdini source can be
fetched by Nix** — neither `pkgs.houdini` nor any houdini-nix build. Before
the first build of a given version you must manually download the matching
production-build installer from <https://www.sidefx.com/download/daily-builds/?production=true>
(login required) and add it to the store:

```bash
nix-store --add-fixed sha256 ~/Downloads/houdini-<version>-linux_x86_64_gcc<gcc>.tar.gz
```

Important details:

- Use the **`.tar.gz`** archive, not the `.iso` — the package's `requireFile`
  matches on the exact tarball name.
- The gcc suffix must match the version (e.g. 22.x builds use `gcc14.2`,
  20.x–21.x use `gcc11.2`, 19.x use `gcc9.3`). The daily-builds page lists it.
- If the hash doesn't match what the package expects, the build fails with a
  `requireFile` error naming the expected file/hash — re-download the exact
  production build for that version.

## License

Houdini is proprietary unfree software. You must have a valid SideFX license
to use it. The module configures `nixpkgs.config.allowUnfree` for Houdini
automatically.

## Notes

- Requires `nixpkgs.config.allowUnfree = true` (set automatically)
- `HFS` environment variable points to the Houdini installation root
- License server can be configured via `licenseServer` (remote) or
  `localLicenseServer.enable` (local sesinetd). They are mutually exclusive.
- The `hserver` (local license daemon) is started automatically when no remote
  license server is configured
- Apprentice NC licenses expire after 30 days — the `houdini-license-redeem.timer`
  re-redeems daily with a randomized 1-hour delay, providing ~29× margin
- The sidefx OAuth application credentials (`sidefx-app` agenix secret) are
  low-value, revocable credentials — the agenix secret's 0400/root mode is
  proportionate to the risk
- All three systemd services (`houdini-api-key`, `houdini-sesinetd`,
  `houdini-license-redeem`) are independently conditional: the cred-render oneshot
  only activates when the agenix secret exists; sesinetd only starts when
  `localLicenseServer` or `redeemNonCommercial` is enabled; redemption only runs
  when both the secret and `redeemNonCommercial.enable` are present
