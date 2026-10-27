# LosslessCut

Swiss-army knife for cutting, splitting, merging and remuxing video/audio
without re-encoding. Cuts snap to keyframes, so trimming a large OBS
recording takes seconds instead of a full transcode.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `my.programs.losslesscut.enable` | `false` | Install LosslessCut |
| `my.programs.losslesscut.package` | `pkgs.losslesscut-bin` | Package to install |

## Usage Example

```nix
my.programs.losslesscut.enable = true;
```

## Notes

- The default `losslesscut-bin` wraps the upstream prebuilt Electron app;
  `pkgs.losslesscut` builds from source against nixpkgs' Electron instead and
  is much heavier to build.
- Lossless edits require the cut to land on a keyframe. OBS can write
  fragmented MP4/WebM; if a cut is rejected, remux first with
  `ffmpeg -i in.mp4 -c copy out.mp4`.
- Enabled by default in the `desktop` home profile
  (`modules/nixos/profiles/home/config.nix`).
