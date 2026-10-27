# OBS Studio

Video recording and live streaming, wrapping Home Manager's `programs.obs-studio`
module so OBS lives under the repo's `my.programs.*` namespace.

## Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | false | Enable OBS Studio |
| `package` | package | `pkgs.obs-studio` | OBS Studio package |
| `plugins` | list of package | `[]` | Plugins wrapped into the package via `wrapOBS` |
| `recordingPath` | null/str | `null` | Recording output directory written into OBS profiles |

## Usage

```nix
my.programs.obs-studio = {
  enable = true;
  plugins = [
    pkgs.obs-studio-plugins.wlrobs
    pkgs.obs-studio-plugins.obs-vkcapture
  ];
};
```

Plugins come from `pkgs.obs-studio-plugins`; they are wrapped into the OBS
package rather than dropped on `PATH`, so OBS finds them at startup.

### Fixed recording directory

```nix
my.programs.obs-studio.recordingPath = "/mnt/data/obs-recordings";
```

On every Home Manager activation this sets `FilePath` (Simple output) plus
`RecFilePath` and `FFFilePath` (Advanced output) in each
`~/.config/obs-studio/basic/profiles/*/basic.ini`, preserving the rest of the
profile via `crudini`. If no profile exists yet, a minimal `Untitled` profile is
created so the first launch already uses the path.

OBS reads these paths only at startup, so **restart OBS after switching**. The
setting is re-applied on every switch, which means changing the recording path
in the OBS UI is not persistent.

The target directory must exist and be writable by the user. For paths outside
`$HOME` add a root-owned tmpfiles rule in the host config; the desktop host
creates `/mnt/data/obs-recordings` for this.

## Notes

- Enabled by default in the `desktop` home profile
  (`modules/nixos/profiles/home/config.nix`).
- The virtual camera is a system-level concern: enable
  `programs.obs-studio.enableVirtualCamera` in the host's NixOS config to load
  `v4l2loopback`. This module only configures the user-level package.
- OBS state (`~/.config/obs-studio/`) is left unmanaged; OBS owns its profiles
  and scene collections.

## Wayland / Hyprland capture

OBS 32.2.2 on Hyprland can SIGSEGV when the PipeWire portal source is selected
(`linux-pipewire.so` `start()` / `on_select_source_response_received_cb`;
upstream obs-studio#13809, wlroots buffer paths also hit #13318). The workaround
is `wlrobs`, which captures via `wlr-screencopy` without xdg-desktop-portal:

```nix
my.programs.obs-studio.plugins = [ pkgs.obs-studio-plugins.wlrobs ];
```

Then add **`Wayland output(scpy)`** as the source. Use the **scpy** backend,
not dmabuf: current OBS crashes in `libwlrobs` dmabuf rendering
(`wl_proxy_marshal_constructor`), matching the AUR report that wlrobs-hg breaks
on OBS 31.1.2+. scpy is the CPU screencopy path and is the stable option here.
wlrobs captures whole outputs only; use OBS crop for a region, or
`obs-vkcapture` for games.
