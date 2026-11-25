# Wallpapers

Static and animated wallpapers for the Hyprland session, including a
**spanning mode** that paints one image/video across every monitor as a single
continuous canvas.

## Backends

| `backend` | Kind | Per-output | Span source |
| --- | --- | --- | --- |
| `hyprpaper` | static image daemon (started from `hyprland.start`) | yes (`wallpaper = OUT,PATH`) | image |
| `swaybg` | static image daemon (systemd user unit) | yes (one process per output) | image |
| `awww` | animated daemon (systemd user unit) | yes (`awww img -o OUT`) | image |
| `mpvpaper` | video wallpaper (systemd user unit) | yes | image or video |
| `waypaper` | GUI frontend, restores one image | no | not supported |

`images = [ { path = …; output = "DP-1"; } … ]` sets explicit files per
output; an entry without `output` applies to all outputs.

## Spanning

Hyprland has no native spanning wallpaper. With `span.enable = true` the module
reads the monitor layout from `my.monitors`, scales the source to the combined
canvas, and crops one file per output **at build time**:

```nix
# the system profile may already set `backend`; override it with lib.mkForce
# if you want a different daemon on one host.
my.desktop.hyprland.wallpapers = {
  span = {
    enable = true;
    source = ./wallpapers/canyon.png;   # image → PNG crops
    fit = "cover";                      # cover | contain | stretch
  };
};
```

For a video source (`mp4`, `webm`, `mkv`, `mov`, `avi`, `m4v`) the module emits
H.264 MP4 crops instead, which only `mpvpaper` can display:

```nix
wallpapers.backend = "mpvpaper";
wallpapers.span.source = ./wallpapers/aurora.mp4;
```

`span.format` forces `image` or `video` when the extension is unusual; `auto`
is the default.

### Geometry

- `my.monitors[].x/y` are logical layout coordinates and may be negative; the
  canvas is their bounding box, so a monitor placed left of/above the origin is
  cropped correctly.
- `width/height` are the mode's pixel size. An odd `transform` (1/3/5/7)
  rotates the output, so the logical box swaps w/h and the emitted file is
  sized to the post-transform pixels (e.g. 1920×1200 rotated 90° → 1200×1920).
- The compositor applies the rotation itself: crops are never pre-rotated.
- `scale` is respected: a 2880×1800 monitor at `scale = 2` occupies 1440×900 in
  the canvas and its crop is resized back to 2880×1800.
- Layouts change only when `my.monitors` changes — regenerate by rebuilding.
  There is no runtime `hyprctl monitors` probe, so a hotplugged monitor that is
  not declared in `my.monitors` gets no span crop.

`span.segments` overrides the automatic crops with manual rectangles in canvas
coordinates (origin = canvas top-left), e.g. for a layout that cannot be
expressed with `my.monitors`:

```nix
wallpapers.span.segments = [
  { output = "DP-3"; x = 0;    y = 0; w = 1200; h = 1920; }
  { output = "DP-1"; x = 1200; y = 240; w = 2560; h = 1440; }
  { output = "DP-2"; x = 3760; y = 0; w = 1200; h = 1920; }
];
```

Manual segments are emitted at the cropped size; each output still receives the
final file through the selected backend.

### Inspecting the result

- `my.desktop.hyprland.wallpapers.span.package` — derivation with
  `<index>-<output>.png|mp4` files.
- `my.desktop.hyprland.wallpapers.resolvedImages` — the files actually applied
  (span crops when enabled, otherwise `images`), useful for scripts:

```bash
nix eval --raw .#nixosConfigurations.desktop.config \
  --apply 'c: builtins.concatStringsSep "\n" (map (i: "${i.output} ${toString i.path}") c.my.desktop.hyprland.wallpapers.resolvedImages)'
```

## Notes

- `cover` scales to fill the canvas (may crop edges), `contain` fits the whole
  image and pads with black, `stretch` distorts to the exact canvas.
- A source at least as large as the total native pixel size gives the sharpest
  result; smaller images are upscaled.
- `waypaper` restores a single image and cannot apply per-output span crops;
  enabling both fails an assertion.
