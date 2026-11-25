# `my.desktop.hyprland.settings`

Every configuration option Hyprland documents — generated from the
[Hyprland wiki](https://wiki.hypr.land/configuring/core/config-options/) and
filtered against the `hl.meta.lua` stubs shipped with Hyprland 0.57.2. The
source of truth is [`spec.nix`](./spec.nix); this page is generated from it.

**Overriding.** Every row is a plain Nix option, so a host overrides it
directly — no `mkForce`:

```nix
my.desktop.hyprland.settings = {
  general.gaps_out = 30;
  decoration.blur.enabled = true;
  decoration.blur.size = 8;
  input.touchpad.natural_scroll = false;
  misc.vrr = 1;
};
```

**Defaults.** The `Default` column is what the repo emits when nothing is
overridden. Hyprland's upstream default is used unless the row is marked
`(repo)`. Where a value is `null`, nothing is emitted and Hyprland's built-in
value applies.

**Types.**

| `type` in spec.nix | Nix type |
| --- | --- |
| `bool` | `bool` |
| `int` / `float` | `int` / `float` |
| `str` | `str` |
| `gap` | `int` or a CSS gap string |
| `intOrStr` | `int` or `str` |
| `gradient` | colour string or `{ colors = [ … ]; angle = 0; }` |
| `vec2` | `{ x = 0; y = 0; }` (rendered as the Lua array `{ x, y }`) |
| `nullable:*` | `null` or the underlying type |

The configured values are rendered into one `hl.config({ … })` call in
`/etc/xdg/hypr/hyprland.lua`.

## Options


### `general`

| Option | Type | Default | Description | Limits |
| --- | --- | --- | --- | --- |
| `border_size` | `int` | `2` (repo) | Size of the border around windows | [0 - 20] |
| `gaps_in` | `css_gaps` | `5` | Gaps between windows |  |
| `gaps_out` | `css_gaps` | `20` | Gaps between windows and monitor edges |  |
| `float_gaps` | `css_gaps` | `0` | Gaps between windows and monitor edges for floating windows `-1` means default. |  |
| `gaps_workspaces` | `int` | `0` | Gaps between workspaces. Stacks with gaps_out | [0 - 100] |
| `col.inactive_border` | `gradient` | palette surface (repo) | Border color for inactive windows |  |
| `col.active_border` | `gradient` | palette accent→accentAlt, 45° (repo) | Border color for the active window |  |
| `col.nogroup_border` | `gradient` | `0xffffaaff` | Border color for inactive windows that cannot be added to a group |  |
| `col.nogroup_border_active` | `gradient` | `0xffff00ff` | Border color for the active window that cannot be added to a group |  |
| `layout` | `string` | `"dwindle"` | Which layout to use. Options: `"dwindle"`/`"master"`/`"scrolling"`/`"monocle"` |  |
| `no_focus_fallback` | `bool` | `false` | If true, will not fall back to the next available window when moving focus in a direction where no window was found |  |
| `resize_on_border` | `bool` | `true` (repo) | Enables resizing windows by clicking and dragging on borders and gaps |  |
| `extend_border_grab_area` | `int` | `15` | Extends the area around the border where you can click and drag on, only used when `general.resize_on_border` is on | [0 - 100] |
| `hover_icon_on_border` | `bool` | `true` | Show a cursor icon when hovering over borders, only used when `general.resize_on_border` is on |  |
| `allow_tearing` | `bool` | `false` | Master switch for allowing tearing to occur. See the [Tearing page](../../extra/tearing) |  |
| `resize_corner` | `int` | `0` | Force floating windows to use a specific corner when being resized (1-4 going clockwise from top left, 0 to disable) | [0 - 4] |
| `snap.enabled` | `bool` | `false` | Enable snapping for floating windows |  |
| `snap.window_gap` | `int` | `10` | Minimum gap in pixels between windows before snapping | [0 - 100] |
| `snap.monitor_gap` | `int` | `10` | Minimum gap in pixels between window and monitor edges before snapping | [0 - 100] |
| `snap.border_overlap` | `bool` | `false` | If enabled, windows snap such that only one border's worth of space is between them |  |
| `snap.respect_gaps` | `bool` | `false` | If enabled, snapping will respect gaps between windows (set in general:gaps_in) |  |
| `modal_parent_blocking` | `bool` | `true` | Whether parent windows of modals will be interactive |  |
| `locale` | `string` | *(unset)* | Overrides the system locale, e.g. `"en_US"`, `"es"` |  |

### `decoration`

| Option | Type | Default | Description | Limits |
| --- | --- | --- | --- | --- |
| `rounding` | `int / `{ top_left?, top_right?, bottom_left?, bottom_right?}`` | `8` (repo) | Rounded corners' radius (in layout px) | [0 - 100] |
| `rounding_power` | `float` | `2.0` | Adjusts the curve used for rounding corners, larger is smoother, 1.0 is a triangular corner, 2.0 is a circle, 4.0 is a squircle | [1.0 - 10.0] |
| `active_opacity` | `float` | `1.0` | Opacity of active windows | [0.0 - 1.0] |
| `inactive_opacity` | `float` | `1.0` | Opacity of inactive windows | [0.0 - 1.0] |
| `fullscreen_opacity` | `float` | `1.0` | Opacity of fullscreen windows | [0.0 - 1.0] |
| `shadow.enabled` | `bool` | `false` (repo; upstream `true`) | Enable drop shadows on windows |  |
| `shadow.range` | `int` | `12` (repo) | Shadow range (size) in pixels | [0 - 100] |
| `shadow.render_power` | `int` | `3` (repo) | In what power to render the falloff. More power, the faster the falloff | [1 - 4] |
| `shadow.sharp` | `bool` | `false` | If enabled, will make the shadows sharp, akin to an infinite render power |  |
| `shadow.color` | `color/gradient` | palette background @ 80% (repo) | Active window shadow's color. Alpha dictates the opacity |  |
| `shadow.color_inactive` | `color/gradient` | *(unset)* | Inactive window shadow's color. If not set, will fall back to `color` |  |
| `shadow.offset` | `vec2` | `{0, 0}` | Shadow's rendering offset |  |
| `shadow.scale` | `float` | `1.0` | Shadow's scale | [0.05 - 2.0] |
| `glow.enabled` | `bool` | `false` | Enable inner glow on windows |  |
| `glow.range` | `int` | `10` | Glow range (size) in pixels | [0 - 100] |
| `glow.render_power` | `int` | `3` | In what power to render the falloff. More power, the faster the falloff | [1 - 4] |
| `glow.color` | `gradient` | `0xee1a1a1a` | Active window glow's color. Alpha dictates opacity |  |
| `glow.color_inactive` | `gradient` | *(unset)* | Inactive window glow's color. If not set, will fall back to `color` |  |
| `dim_modal` | `bool` | `true` | Enables dimming of parents of modal windows |  |
| `dim_inactive` | `bool` | `false` | Enables dimming of inactive windows |  |
| `dim_strength` | `float` | `0.5` | How much inactive windows should be dimmed | [0.0 - 1.0] |
| `dim_special` | `float` | `0.2 ` | How much to dim the rest of the screen by when a special workspace is open. [0.0 - 1.0] |  |
| `dim_around` | `float` | `0.4` | How much the `dim_around` window rule should dim by | [0.0 - 1.0] |
| `screen_shader` | `string` | *(unset)* | A path to a custom shader to be applied at the end of rendering. See `examples/screenShader.frag` for an example |  |
| `border_part_of_window` | `bool` | `true` | Whether the window border should be a part of the window |  |
| `blur.enabled` | `bool` | `false` (repo; upstream `true`) | Enable kawase window background blur |  |
| `blur.variant` | `string` | `kawase` | Blur pattern variant. May significantly increase GPU and CPU usage | [see below](#blur-variants) |
| `blur.size` | `int` | `6` (repo) | Blur size (distance) |  |
| `blur.passes` | `int` | `2` (repo) | The amount of passes to perform | [0 - 10] |
| `blur.ignore_opacity` | `bool` | `true` | Make the blur layer ignore the opacity of the window |  |
| `blur.new_optimizations` | `bool` | `true` | Whether to enable further optimizations to the blur. Recommended to leave on, as it will massively improve performance |  |
| `blur.xray` | `bool` | `false` | If enabled, floating windows will ignore tiled windows in their blur. Will reduce overhead on floating blur significantly. Disabled if `new_optimizations = false` |  |
| `blur.proportional` | `bool` | `false` | If enabled, blur strength will be proportional to pixel opacity. Requires `render:use_shader_blur_blend` |  |
| `blur.noise` | `float` | `0.0117` | How much noise to apply | [0.0 - 1.0] |
| `blur.contrast` | `float` | `0.8916` | Contrast modulation for blur | [0.0 - 2.0] |
| `blur.brightness` | `float` | `1` | Brightness modulation for blur | [0.0 - 2.0] |
| `blur.vibrancy` | `float` | `0.1696` | Increase saturation of blurred colors | [0.0 - 1.0] |
| `blur.vibrancy_darkness` | `float` | `0.0` | How strong the effect of `vibrancy` is on dark areas | [0.0 - 1.0] |
| `blur.special` | `bool` | `false` | Whether to blur behind the special workspace (note: expensive) |  |
| `blur.popups` | `bool` | `false` | Whether to blur popups, e.g. `right-click menus` |  |
| `blur.popups_ignorealpha` | `float` | `0.2` | Works like ignore_alpha in layer rules. If pixel opacity is below the set value, will not blur | [0.0 - 1.0] |
| `blur.input_methods` | `bool` | `false` | Whether to blur input methods, e.g. `fcitx5` |  |
| `blur.input_methods_ignorealpha` | `float` | `0.2` | Works like ignore_alpha in layer rules. If pixel opacity is below the set value, will not blur | [0.0 - 1.0] |
| `blur.glass.refraction` | `float` | `20.0` | Maximum refraction displacement for glass blur types in pixels | [0.0 - 20.0] |
| `blur.glass.size` | `float` | `40.0` | Pattern size for glass blur types in pixels | [4.0 - 512.0] |
| `blur.glass.roughness` | `float` | `1.0` | Strength of the glass relief shading | [0.0 - 1.0] |
| `blur.acrylic.refraction` | `float` | `24.0` | Maximum acrylic lens displacement in pixels | [0.0 - 48.0] |
| `blur.acrylic.bulb` | `float` | `48.0` | Width of the curved acrylic edge in pixels | [4.0 - 256.0] |
| `blur.acrylic.clarity` | `float` | `0.82` | Amount of sharp backdrop passing through the acrylic surface | [0.0 - 1.0] |
| `blur.acrylic.aberration` | `float` | `0.025` | Relative chromatic separation in the acrylic lens | [0.0 - 0.25] |
| `blur.acrylic.tint` | `color` | `0x14EEF5FF` | Acrylic tint color. Alpha channel controls optical absorption |  |
| `blur.drops.speed` | `float` | `3.0` | Animation speed. 0 disables the animation | [0.0 - 10.0] |
| `blur.heat_shimmer.speed` | `float` | `1.0` | Animation speed. 0 disables the animation | [0.0 - 10.0] |
| `blur.aurora.speed` | `float` | `1.0` | Animation speed. 0 freezes the animation | [0.0 - 10.0] |
| `blur.aurora.intensity` | `float` | `0.35` | Strength of the aurora color contribution | [0.0 - 1.0] |
| `blur.aurora.color1` | `color` | `0x29F0A0FF` | First aurora curtain color. Alpha controls its contribution |  |
| `blur.aurora.color2` | `color` | `0x7A4DFFFF` | Second aurora curtain color. Alpha controls its contribution |  |
| `blur.haze.intensity` | `float` | `0.35` | Strength of the haze pearlescent sheen | [0.0 - 1.0] |
| `blur.haze.iridescence` | `float` | `0.7` | Strength of the haze pearlescent color shift | [0.0 - 1.0] |
| `blur.ripple.strength` | `float` | `30.0` | Maximum refraction displacement in pixels | [0.0 - 32.0] |
| `blur.ripple.radius` | `float` | `400.0` | Maximum radius in pixels | [1.0 - 1000.0] |
| `blur.ripple.width` | `float` | `32.0` | Width of waves in pixels | [1.0 - 200.0] |
| `blur.ripple.duration` | `float` | `0.45` | Duration in seconds | [0.05 - 5.0] |
| `blur.water.strength` | `float` | `32.0` | Maximum refraction displacement and injection strength in pixels | [0.0 - 32.0] |
| `blur.water.radius` | `float` | `20.0` | Pointer radius in pixels | [1.0 - 1000.0] |
| `blur.water.speed` | `float` | `0.76` | Propagation speed | [0.0 - 10.0] |
| `blur.water.damping` | `float` | `0.95` | Decay damping | [0.0 - 1.0] |
| `blur.water.duration` | `float` | `12.0` | Maximum duration in seconds | [0.5 - 60.0] |
| `blur.fluid_jar.color` | `color` | `0xCC3399FF` | Fluid color |  |
| `blur.fluid_jar.speed` | `float` | `3.7` | Animation speed | [0.0 - 10.0] |
| `blur.fluid_jar.fill_amount` | `float` | `0.5` | Fill level for of the fluid | [0.0 - 1.0] |
| `blur.fluid_jar.mass` | `float` | `1.4` | Fluid's Inertial mass | [0.1 - 10.0] |
| `blur.fluid_jar.precision` | `float` | `2.0` | Fluid simulation precision multiplier. 2x is a good compromise. 4x is expensive. 8x is extreme and unnecessary | [0.5 - 8.0] |
| `blur.fluid_jar.turbulence` | `float` | `1.2` | Interior fluid turbulence multiplier | [0.0 - 5.0] |
| `blur.fluid_jar.distortion` | `float` | `8.0` | Fluid refraction distortion multiplier | [0.0 - 10.0] |
| `motion_blur.enabled` | `bool` | `false` | enable motion blur on moving/resizing windows |  |
| `motion_blur.samples` | `int` | `7` | The amount of samples to render. More will mean clearer blur, at the cost of more compute | [1 - 64] |
| `wobble.enabled` | `bool` | `false` | enable wobble on moving/resizing windows |  |
| `wobble.mesh` | `int` | `12` | amount of wobble mesh vertices per edge | [2 - 32] |
| `wobble.stiffness` | `float` | `200` | spring stiffness for wobble deformation | [0.0001 - 1000] |
| `wobble.damping` | `float` | `12` | spring damping for wobble deformation | [0 - 1000] |
| `wobble.mass` | `float` | `1` | spring mass for wobble deformation | [0.0001 - 1000] |
| `wobble.intensity` | `float` | `0.2` | wobble deformation impulse multiplier | [0 - 2] |
| `wobble.value_epsilon` | `float` | `0.25` | position epsilon below which wobble is considered stable | [0 - 100] |
| `wobble.velocity_epsilon` | `float` | `2` | velocity epsilon below which wobble is considered stable | [0 - 1000] |

### `animations`

| Option | Type | Default | Description | Limits |
| --- | --- | --- | --- | --- |
| `enabled` | `bool` | `true` | Enable animations |  |
| `workspace_wraparound` | `bool` | `false` | Enable workspace wraparound, causing directional workspace animations to animate as if the first and last workspaces were adjacent |  |

### `input`

| Option | Type | Default | Description | Limits |
| --- | --- | --- | --- | --- |
| `kb_model` | `string` | *(unset)* | Appropriate XKB keymap parameter. See the note [below](#xkb-keymap-params) |  |
| `kb_layout` | `string` | `"us"` | Appropriate XKB keymap parameter |  |
| `kb_variant` | `string` | *(unset)* | Appropriate XKB keymap parameter |  |
| `kb_options` | `string` | *(unset)* | Appropriate XKB keymap parameter |  |
| `kb_rules` | `string` | *(unset)* | Appropriate XKB keymap parameter |  |
| `kb_file` | `string` | *(unset)* | If you prefer, you can use a path to your custom .xkb file |  |
| `numlock_by_default` | `bool` | `false` | Enable numlock by default |  |
| `resolve_binds_by_sym` | `bool` | `false` | Determines how keybinds act when multiple layouts are used. If false, keybinds will always act as if the first specified layout is active. If true, keybinds specified by symbols are activated when you type the respective symbol with the current layout |  |
| `repeat_rate` | `int` | `25` | The repeat rate for held-down keys, in repeats per second | [0 - 200] |
| `repeat_delay` | `int` | `600` | Delay before a held-down key is repeated, in milliseconds | [0 - 2000] |
| `sensitivity` | `float` | `0.0` | Sets the mouse input sensitivity. Additional info: [libinput#pointer-acceleration](https://wayland.freedesktop.org/libinput/doc/latest/pointer-acceleration.html#pointer-acceleration) | [-1.0 - 1.0] |
| `accel_profile` | `string` | *(unset)* | Sets the cursor acceleration profile. See the note [below](#accel-profile). Leave empty to use `libinput`'s default mode for your input device. [libinput#pointer-acceleration](https://wayland.freedesktop.org/libinput/doc/latest/pointer-acceleration.html#pointer-acceleration). Options: `"adaptive"`/`"flat"`/`"custom"` |  |
| `force_no_accel` | `bool` | `false` | Force no cursor acceleration. This bypasses most of your pointer settings to get as raw of a signal as possible. **Enabling this is not recommended due to potential cursor desynchronization.** |  |
| `rotation` | `int` | `0` | Sets the rotation of a device in degrees clockwise off the logical neutral position | [0 - 359] |
| `left_handed` | `bool` | `false` | Switches RMB and LMB |  |
| `scroll_points` | `string` | *(unset)* | Sets the scroll acceleration profile, when `accel_profile` is set to `"custom"`. Has to be in the form `"<step> <points>"`. Leave empty to have a flat scroll curve |  |
| `scroll_method` | `string` | *(unset)* | Sets the scroll method. Additional info: [libinput#scrolling](https://wayland.freedesktop.org/libinput/doc/latest/scrolling.html). Options: `"2fg"`/`"edge"`/`"on_button_down"`/`"no_scroll"` (2fg - 2 fingers) |  |
| `scroll_button` | `int` | `0` | Sets the scroll button. Check `wev` for the ID. `0` means default | [0 - 300] |
| `scroll_button_lock` | `bool` | `false` | If the scroll button lock is enabled, the button does not need to be held down. Pressing and releasing the button toggles the button lock, which logically holds the button down or releases it. While the button is logically held down, motion events are converted to scroll events |  |
| `scroll_factor` | `float` | `1.0` | Multiplier added to scroll movement for external mice. Note that there is a separate setting for [touchpad scroll_factor](#touchpad) | [0 - 100] |
| `natural_scroll` | `bool` | `false` | Inverts scrolling direction. When enabled, scrolling moves content directly, rather than manipulating a scrollbar |  |
| `follow_mouse` | `int` | `1` | Specify if and how cursor movement should affect window focus. See the note [below](#follow-mouse) | [0 - 3] |
| `follow_mouse_threshold` | `float` | `0.0` | The smallest distance in logical pixels the mouse needs to travel for the window under it to get focused. Works only with `follow_mouse` set to`1` |  |
| `swallow_focus_click` | `bool` | `false` | If enabled, the first click on unfocused window will focus it without forwarding the click action. Only relevant when mouse focus is detached, e.g. `input.follow_mouse` is `0` or `2` |  |
| `focus_on_close` | `int` | `0` | Controls the window focus behavior when a window is closed. When set to `0`, focus will shift to the next window candidate. When set to `1`, focus will shift to the window under the cursor. When set to `2`, focus will shift to the most recently used/active window | [0 - 2] |
| `mouse_refocus` | `bool` | `true` | If enabled, mouse focus will switch to the hovered window when the pointer crosses a window boundary. Works only with `follow_mouse` set to `1` |  |
| `float_switch_override_focus` | `int` | `1` | If `1`/`2` focus will change to the window under the cursor when changing from tiled-to-floating and vice versa. If `2`, focus will also follow mouse on float-to-float switches. `0` means disabled | [0 - 2] |
| `special_fallthrough` | `bool` | `false` | If enabled, having only floating windows in the special workspace will not block focusing windows in the regular workspace |  |
| `off_window_axis_events` | `int` | `1` | Handles axis events around (gaps/border for tiled, dragarea/border for floated) a focused window. `0` ignores axis events `1` sends out-of-bound coordinates `2` fakes pointer coordinates to the closest point inside the window `3` warps the cursor to the closest point inside the window | [0 - 3] |
| `emulate_discrete_scroll` | `int` | `1` | Emulates discrete scrolling from high resolution scrolling events. `0` disables it, `1` enables handling of non-standard events only, and `2` force enables all scroll wheel events to be handled | [0 - 2] |
| `follow_mouse_shrink` | `int` | `0` | Shrinks the inactive window hitboxes used for focus detection by the specified number of pixels. This creates a dead zone in gaps between windows where moving the cursor will not change focus. Works only with `follow_mouse` set to `1` | [0 - 300] |
| `touchpad.disable_while_typing` | `bool` | `true` | Disable the touchpad while typing |  |
| `touchpad.natural_scroll` | `bool` | `true` (repo) | Inverts scrolling direction. When enabled, scrolling moves content directly, rather than manipulating a scrollbar |  |
| `touchpad.scroll_factor` | `float` | `1.0` | Multiplier applied to the amount of scroll movement | [0.0 - 100] |
| `touchpad.middle_button_emulation` | `bool` | `false` | Sending LMB and RMB simultaneously will be interpreted as a middle click. This disables any touchpad area that would normally send a middle click based on location. Additional info: [libinput#middle-button-emulation](https://wayland.freedesktop.org/libinput/doc/latest/middle-button-emulation.html) |  |
| `touchpad.tap_button_map` | `string` | *(unset)* | Sets the tap button mapping for touchpad button emulation. When empty, defaults to `"lrm"`. L - Left, M - Middle, R - Right | "lrm"/"lmr" |
| `touchpad.clickfinger_behavior` | `bool` | `false` | Button presses with 1, 2, or 3 fingers will be mapped to LMB, RMB, and MMB respectively. This disables interpretation of clicks based on location on the touchpad. Additional info: [libinput#clickfinger-behavior](https://wayland.freedesktop.org/libinput/doc/latest/clickpad-softbuttons.html#clickfinger-behavior) |  |
| `touchpad.tap_to_click` | `bool` | `true` | Tapping on the touchpad with 1, 2, or 3 fingers will send LMB, RMB, and MMB respectively |  |
| `touchpad.drag_lock` | `int` | `1` (repo) | When enabled, lifting the finger off while dragging will not drop the dragged item. 0 - disabled, 1 - enabled with timeout, 2 - enabled sticky. Additional info: [libinput#tap-and-drag](https://wayland.freedesktop.org/libinput/doc/latest/tapping.html#tap-and-drag) | [0 - 2] |
| `touchpad.tap_and_drag` | `bool` | `true` | Sets the tap and drag mode for the touchpad |  |
| `touchpad.flip_x` | `bool` | `false` | Inverts the horizontal movement of the touchpad |  |
| `touchpad.flip_y` | `bool` | `false` | Inverts the vertical movement of the touchpad |  |
| `touchpad.drag_3fg` | `int` | `0` | Enables three finger drag. Additional info: [libinput#drag-3fg](https://wayland.freedesktop.org/libinput/doc/latest/drag-3fg.html) | [0 - 2] |
| `touchdevice.transform` | `int` | `0` | Transform the input from touchdevices. The possible transformations are the same as [those of the monitors](../monitors/positioning#rotation) | [0 - 6] |
| `touchdevice.output` | `string` | *(unset)* | The monitor to bind touch devices. The default is auto-detection. To stop auto-detection, use an empty string |  |
| `touchdevice.enabled` | `bool` | `true` | Whether input is enabled for touch devices |  |
| `virtualkeyboard.share_states` | `int` | `2` | Unify key down states and modifier states with other keyboards. 0 - no, 1 - yes, 2 - yes unless IME client | [0 - 2] |
| `virtualkeyboard.release_pressed_on_close` | `bool` | `false` | Release all pressed keys by virtual keyboard on close |  |
| `tablet.enabled` | `bool` | `true` | Whether input is enabled for tablets |  |
| `tablet.transform` | `int` | `0` | Transform the input from tablets. The possible transformations are the same as [those of the monitors](../monitors/positioning#rotation) | [0 - 6] |
| `tablet.output` | `string` | *(unset)* | The monitor to bind tablets. Can be `"current"` or a monitor name. Leave empty to map across all monitors |  |
| `tablet.region_position` | `vec2` | `{0, 0}` | Position of the mapped region in monitor layout relative to the top left corner of the bound monitor or all monitors | [-100000 - 100000] |
| `tablet.absolute_region_position` | `bool` | `false` | Whether to treat the `region_position` as an absolute position in monitor layout. Only applies when `output` is empty |  |
| `tablet.region_size` | `vec2` | *(unset)* (repo; upstream `{0, 0}` is rejected) | Size of the mapped region. When this variable is set, tablet input will be mapped to the region. `{0, 0}` or invalid size means unset | [1 - 100000] |
| `tablet.relative_input` | `bool` | `false` | Whether the input should be relative |  |
| `tablet.left_handed` | `bool` | `false` | If enabled, the tablet will be rotated 180 degrees |  |
| `tablet.active_area_size` | `vec2` | `{0, 0}` | Size of tablet's active area in mm | [0 - 5000] |
| `tablet.active_area_position` | `vec2` | `{0, 0}` | Position of the active area in mm | [0 - 5000] |
| `tablettool.eraser_button_mode` | `int` | `0` | Change the eraser button behavior on the tool. When set to `0`, use the default hardware behavior of the tool. When set to `1`, the eraser button on the tool sends a button event instead | [0 - 6] |
| `tablettool.eraser_button_override` | `int` | `0` | Set a button to be button event when eraser_button_mode is set to `1`. Must be a valid button (e.g., BTN_STYLUS) excluding fake buttons (e.g., BTN_TOOL_\*) and keys (KEY_\*). Check `wev` for the ID. `0` means default | [0 - ...] |
| `tablettool.pressure_range_min` | `float` | `-1.0` | Set the minimum pressure range for the tool. Negative values mean it will use device defaults. Usually it is `0.0` | [-1.0 - 1.0] |
| `tablettool.pressure_range_max` | `float` | `-1.0` | Set the maximum pressure range for the tool. Negative values mean it will use device defaults. Usually it is `1.0` | [-1.0 - 1.0] |

### `gestures`

| Option | Type | Default | Description | Limits |
| --- | --- | --- | --- | --- |
| `workspace_swipe_distance` | `int` | `300` | In pixels, the distance of the touchpad gesture | [0 - 2000] |
| `workspace_swipe_touch` | `bool` | `false` | Enable workspace swiping from the edge of a touchscreen |  |
| `workspace_swipe_invert` | `bool` | `true` | Invert the swipe direction (touchpad only) |  |
| `workspace_swipe_touch_invert` | `bool` | `false` | Invert the swipe direction (touchscreen only) |  |
| `workspace_swipe_min_speed_to_force` | `int` | `30` | Minimum speed in pixels per timepoint to force the change ignoring `cancel_ratio`. `0` means disabled | [0 - 200] |
| `workspace_swipe_cancel_ratio` | `float` | `0.5` | How much the swipe has to proceed in order to commence it. Example, when set to `0.7`: if more than 70% of the distance is covered, switch; else, cancel the gesture | [0.0 - 1.0] |
| `workspace_swipe_create_new` | `bool` | `true` | Whether a swipe right on the last workspace should create a new one |  |
| `workspace_swipe_direction_lock` | `bool` | `true` | If enabled, switching direction will be locked when you swipe past the `direction_lock_threshold` (touchpad only) |  |
| `workspace_swipe_direction_lock_threshold` | `int` | `10` | In pixels, the distance to swipe before direction lock activates (touchpad only) | [0 - 200] |
| `workspace_swipe_forever` | `bool` | `false` | If enabled, swiping will not clamp at the neighboring workspaces but continue to the further ones |  |
| `workspace_swipe_use_r` | `bool` | `false` | If enabled, swiping will use the `r` prefix instead of the `m` prefix for finding workspaces |  |
| `close_max_timeout` | `int` | `1000` | The timeout for a window to close when using a 1:1 gesture, in ms | [10 - 2000] |
| `scrolling.move_snap_to_grid` | `bool` | `true` | When releasing the scroll move gesture, whether it should try to snap to the grid |  |
| `scrolling.move_snap_cursor` | `bool` | `true` | When releasing the scroll move gesture, whether it should snap the cursor to the newly focused window |  |

### `group`

| Option | Type | Default | Description | Limits |
| --- | --- | --- | --- | --- |
| `insert_after_current` | `bool` | `true` | Whether new windows in a group spawn after current or at group tail |  |
| `focus_removed_window` | `bool` | `true` | Whether Hyprland should focus on the window that has just been moved out of the group |  |
| `merge_groups_on_drag` | `bool` | `true` | Whether window groups can be dragged into other groups |  |
| `merge_groups_on_groupbar` | `bool` | `true` | Whether one group will be merged with another when dragged into its groupbar. *Note: enabling this option only works when combined with `drag_into_group = 2` and `merge_groups_on_drag = true`* |  |
| `col.border_active` | `gradient` | `0x66ffff00` | Active group border color. Has additional `whole_monitor? = bool` parameter in the gradient |  |
| `col.border_inactive` | `gradient` | `0x66777700` | Inactive group border color. Has additional `whole_monitor? = bool` parameter in the gradient |  |
| `col.border_locked_inactive` | `gradient` | `0x66775500` | Inactive locked group border color. Has additional `whole_monitor? = bool` parameter in the gradient |  |
| `col.border_locked_active` | `gradient` | `0x66ff5500` | Active locked group border color. Has additional `whole_monitor? = bool` parameter in the gradient |  |
| `auto_group` | `bool` | `true` | Whether new windows will be automatically grouped into the focused unlocked group. *Note: if you want to disable auto_group only for specific windows, use [the "group barred" window rule](../rules/window-rules/#group-window-rule-options) instead* |  |
| `drag_into_group` | `int` | `1` | Whether dragging a window into an unlocked group will merge them. `0` - disabled, `1` - enabled, `2` - only when dragging into a groupbar | [0 - 2] |
| `merge_floated_into_tiled_on_groupbar` | `bool` | `false` | Whether dragging a floating window into a tiled window groupbar will merge them |  |
| `group_on_movetoworkspace` | `bool` | `false` | Whether using hl.dsp.window.move({ workspace }) will merge the window into the workspace's solitary unlocked group |  |
| `groupbar.enabled` | `bool` | `true` | Enables groupbars |  |
| `groupbar.disable_when_only` | `bool` | `false` | Disable groupbar if it contains a single window |  |
| `groupbar.font_family` | `string` | *(unset)* | Font used to display groupbar titles, use `misc.font_family` if not specified |  |
| `groupbar.font_weight_active` | `font_weight` | `"normal"` | Font weight of active groupbar title |  |
| `groupbar.font_weight_inactive` | `font_weight` | `"normal"` | Font weight of inactive groupbar title |  |
| `groupbar.font_size` | `int` | `8` | Font size of groupbar title | [2 - 64] |
| `groupbar.gradients` | `bool` | `false` | Enables gradients |  |
| `groupbar.height` | `int` | `14` | Height of the groupbar | [0 - 64] |
| `groupbar.indicator_gap` | `int` | `0` | Height of gap between groupbar indicator and title | [0 - 64] |
| `groupbar.indicator_height` | `int` | `3` | Height of the groupbar indicator | [0 - 64] |
| `groupbar.stacked` | `bool` | `false` | Render the groupbar as a vertical stack |  |
| `groupbar.priority` | `int` | `3` | Sets the decoration priority for groupbars | [0 - 6] |
| `groupbar.render_titles` | `bool` | `true` | Whether to render titles in the group bar decoration |  |
| `groupbar.scrolling` | `bool` | `true` | Whether scrolling in the groupbar changes group active window |  |
| `groupbar.middle_click_close` | `bool` | `true` | Whether middle clicking the groupbar closes the clicked window |  |
| `groupbar.rounding` | `int` | `1` | How much to round the indicator | [0 - 40] |
| `groupbar.rounding_power` | `float` | `2.0` | Adjusts the curve used for rounding groupbar corners, larger is smoother, 1.0 is a triangular corner, 2.0 is a circle, 4.0 is a squircle | [1.0 - 10.0] |
| `groupbar.gradient_rounding` | `int` | `2` | How much to round the gradients | [0 - 100] |
| `groupbar.gradient_rounding_power` | `float` | `2.0` | Adjusts the curve used for rounding gradient corners, larger is smoother, 1.0 is a triangular corner, 2.0 is a circle, 4.0 is a squircle | [1.0 - 10.0] |
| `groupbar.round_only_edges` | `bool` | `true` | Round only the indicator edges of the entire groupbar |  |
| `groupbar.gradient_round_only_edges` | `bool` | `true` | Round only the gradient edges of the entire groupbar |  |
| `groupbar.text_color` | `color` | `0xffffffff` | Color for window titles in the groupbar |  |
| `groupbar.text_color_inactive` | `color` | *(unset)* | Color for inactive windows' titles in the groupbar, if unset, defaults to text_color |  |
| `groupbar.text_color_locked_active` | `color` | *(unset)* | Color for the active window's title in a locked group, if unset, defaults to text_color |  |
| `groupbar.text_color_locked_inactive` | `color` | *(unset)* | Color for inactive windows' titles in locked groups, if unset, defaults to text_color_inactive |  |
| `groupbar.col.active` | `gradient` | `0x66ffff00` | Active group bar background color |  |
| `groupbar.col.inactive` | `gradient` | `0x66777700` | Inactive (out of focus) group bar background color |  |
| `groupbar.col.locked_active` | `gradient` | `0x66ff5500` | Active locked group bar background color |  |
| `groupbar.col.locked_inactive` | `gradient` | `0x66775500` | Inactive locked group bar background color |  |
| `groupbar.gaps_out` | `int` | `2` | Gap size between gradients and window | [0 - 20] |
| `groupbar.gaps_in` | `int` | `2` | Gap size between gradients | [0 - 20] |
| `groupbar.keep_upper_gap` | `bool` | `true` | Add or remove upper gap |  |
| `groupbar.text_offset` | `int` | `0` | Adjust vertical position for titles | [-20 - 20] |
| `groupbar.text_padding` | `int` | `0` | Set horizontal padding for titles | [0 - 22] |
| `groupbar.blur` | `bool` | `false` | Applies blur to the groupbar indicators and gradients |  |

### `misc`

| Option | Type | Default | Description | Limits |
| --- | --- | --- | --- | --- |
| `disable_hyprland_logo` | `bool` | `true` (repo) | Disables the random Hyprland logo/anime girl background. :( |  |
| `disable_splash_rendering` | `bool` | `false` | Disables the Hyprland splash rendering (the small random bit of text on the background). Requires a monitor reload to take effect. Note hyprpaper has its own setting to disable it |  |
| `col.splash` | `color` | `0x55ffffff` | Changes the color of the splash text (requires a monitor reload to take effect) |  |
| `font_family` | `string` | `"Sans"` | Sets the global default font used to render text |  |
| `splash_font_family` | `string` | *(unset)* | Changes the font used to render the splash text, selected from system fonts (requires a monitor reload to take effect) |  |
| `force_default_wallpaper` | `int` | `0` (repo) | Enforce any of the 3 default wallpapers. 0 - disables the anime background, 1 - disables the anime background, 2 - enables anime background, -1 - random | [-1 - 2] |
| `vrr` | `int` | `0` | Controls the VRR (Adaptive Sync) of your monitors. 0 - off, 1 - on, 2 - fullscreen only, 3 - fullscreen with `video` or `game` content type | [0 - 3] |
| `mouse_move_enables_dpms` | `bool` | `false` | If DPMS is set to off, wake up the monitors if the mouse moves |  |
| `key_press_enables_dpms` | `bool` | `false` | If DPMS is set to off, wake up the monitors if a key is pressed |  |
| `name_vk_after_proc` | `bool` | `true` | Name virtual keyboards after the processes that create them, e.g. `/usr/bin/fcitx5` will have hl-virtual-keyboard-fcitx5 |  |
| `always_follow_on_dnd` | `bool` | `true` | Will make mouse focus follow the mouse when dragging and dropping. Recommended to leave it enabled, especially for people using focus follows mouse at 0 |  |
| `layers_hog_keyboard_focus` | `bool` | `true` | If true, will make keyboard-interactive layers keep their focus on mouse move, e.g. `wofi`, `bemenu` |  |
| `animate_manual_resizes` | `bool` | `false` | If true, will animate manual window resizes/moves |  |
| `animate_mouse_windowdragging` | `bool` | `false` | If true, will animate windows being dragged by mouse, note that this can cause weird behavior on some curves |  |
| `disable_autoreload` | `bool` | `false` | If true, the config will not reload automatically on save, and instead needs to be reloaded with `hyprctl reload`. Might save on battery |  |
| `enable_swallow` | `bool` | `false` | Enable window swallowing |  |
| `swallow_regex` | `string` | *(unset)* | The _class_ regex to be used for windows that should be swallowed (usually, a terminal) |  |
| `swallow_exception_regex` | `string` | *(unset)* | The _title_ regex to be used for windows that should _not_ be swallowed by the windows specified in swallow_regex, e.g. `wev`. The regex is matched against the parent, e.g. Kitty, window's title on the assumption that it changes to whatever process it's running |  |
| `focus_on_activate` | `bool` | `false` | Whether Hyprland should focus an app that requests to be focused (an `activate` request) |  |
| `mouse_move_focuses_monitor` | `bool` | `true` | Whether mouse moving into a different monitor should focus it |  |
| `allow_session_lock_restore` | `bool` | `false` | If true, will allow you to restart a lock screen app in case it crashes |  |
| `session_lock_xray` | `bool` | `false` | If true, keep rendering workspaces below your lock screen |  |
| `session_lock_blur` | `bool` | `false` | Enables blur for lock screen. `session_lock_xray` must be enabled |  |
| `background_color` | `color` | `0x111111` | Change the background color (requires enabled `disable_hyprland_logo`) |  |
| `close_special_on_empty` | `bool` | `true` | Close the special workspace if the last window is removed |  |
| `on_focus_under_fullscreen` | `int` | `2` | If there is a fullscreen or maximized window, decide whether a tiled window requested to focus should replace it, stay behind or disable the fullscreen/maximized state. 0 - ignore focus request (keep focus on fullscreen window), 1 - takes over, 2 - unfullscreen/unmaximize | [0 - 2] |
| `exit_window_retains_fullscreen` | `int` | `0` | Whether closing a fullscreen window makes the next focused window to be fullscreened. 0 - disabled, 1 - enabled, 2 - only when closing a grouped window, 3 - only when closing a non-grouped window | [0 - 3] |
| `initial_workspace_tracking` | `int` | `1` | If enabled, windows will open on the workspace they were invoked on. 0 - disabled, 1 - single-shot, 2 - persistent (all children too) |  |
| `initial_workspace_token_timeout` | `int` | `10` | the time in seconds a window has to open on its invoked workspace before the tracking token expires. | [1 - 3600] |
| `middle_click_paste` | `bool` | `true` | Whether to enable middle-click-paste (aka primary selection) |  |
| `render_unfocused_fps` | `int` | `15` | The maximum limit for render_unfocused windows' FPS in the background (see also [Window-Rules](../rules/window-rules/#dynamic-effects), e.g. `render_unfocused`) | [1 - 120] |
| `disable_xdg_env_checks` | `bool` | `false` | Disable the warning if XDG environment is externally managed |  |
| `disable_hyprland_guiutils_check` | `bool` | `false` | Disable the warning if hyprland-guiutils is not installed |  |
| `disable_watchdog_warning` | `bool` | `false` | Disables the warning about not using start-hyprland |  |
| `lockdead_screen_delay` | `int` | `1000` | Delay in ms after which the "lockdead" screen will appear in case a lock screen app fails to cover all the outputs | [0 - 5000] |
| `enable_anr_dialog` | `bool` | `true` | Whether to enable the ANR (app not responding) dialog when your apps hang |  |
| `anr_missed_pings` | `int` | `5` | Number of missed pings before showing the ANR dialog | [1 - 20] |
| `screencopy_force_8b` | `bool` | `true` | Forces 8 bit screencopy |  |
| `disable_scale_notification` | `bool` | `false` | Disables notification popup when a monitor fails to set a suitable scale |  |
| `size_limits_tiled` | `bool` | `false` | Whether to apply min_size and max_size rules to tiled windows |  |
| `bell_sound` | `string` | `"default"` | Path to custom wav/ogg system bell. "none" or an empty string mutes it. "default" uses the system's current one |  |
| `new_float_force_onscreen` | `int` | `2` | same as `float_force_onscreen`, but specifically for newly-spawned floating windows | [0 - 2] |
| `float_force_onscreen` | `int` | `0` | whether/how existing floating windows should be constrained to stay on-screen. 0 - no constraints, 1 - must be partially onscreen, 2 - must be fully onscreen | [0 - 2] |

### `layers`

| Option | Type | Default | Description | Limits |
| --- | --- | --- | --- | --- |
| `allow_new_top_layers_over_existing_fullscreen` | `bool` | `true` | If false, newly mapped layers are not allowed to render over existing covering fullscreen window. Note that fullscreen hides all pre-existing top layers regardless of this setting |  |
| `layers_hog_keyboard_focus` | `bool` | `true` | If true, will make keyboard-interactive layers keep their focus on mouse move, e.g. `wofi`, `bemenu` |  |

### `binds`

| Option | Type | Default | Description | Limits |
| --- | --- | --- | --- | --- |
| `pass_mouse_when_bound` | `bool` | `false` | If enabled, will pass the mouse events to apps/dragging windows around if a keybind has been triggered |  |
| `scroll_event_delay` | `int` | `300` | In ms, how many ms to wait after a scroll event to allow passing another one for the binds | [0 - 2000] |
| `workspace_back_and_forth` | `int` | `0` | An attempt to switch to the currently focused workspace will instead switch to the previous workspace, akin to i3's `_auto_back_and_forth_`. `0` - disabled, `1` - enabled, `2` - per monitor | [0 - 2] |
| `hide_special_on_workspace_change` | `bool` | `false` | If enabled, changing the active workspace (including to itself) will hide the special workspace on the monitor where the newly active workspace resides |  |
| `allow_workspace_cycles` | `bool` | `false` | If enabled, workspaces don't forget their previous workspace, so cycles can be created by switching to the first workspace in a sequence, then endlessly going to the previous workspace |  |
| `workspace_center_on` | `int` | `1` | Whether switching workspaces should center the cursor on the workspace (0) or on the last active window for that workspace (1) | [0 - 1] |
| `focus_preferred_method` | `int` | `0` | Sets the preferred focus finding method when using `hl.dsp.focus({ direction })`/`hl.dsp.window.move({ direction })`/etc. `0` - most recent active window has priority, `1` - longer shared edges have priority) | [0 - 1] |
| `ignore_group_lock` | `bool` | `false` | If enabled, dispatchers like `hl.dsp.window.move({ into_group })` and `hl.dsp.window.move({ out_of_group })` will ignore lock per group |  |
| `movefocus_cycles_fullscreen` | `bool` | `false` | If enabled, when focus is on a fullscreen window, it allows `hl.dsp.focus({ direction })` to seek windows. If disabled, it will seek just monitors. |  |
| `movefocus_cycles_groupfirst` | `bool` | `false` | If enabled, when in a grouped window, `hl.dsp.focus({ direction })` will cycle windows in the groups first, then at each ends of the tabs, it'll move on to other windows/groups |  |
| `disable_keybind_grabbing` | `bool` | `false` | If enabled, apps that request keybinds to be disabled, e.g. `VMs`, will not be able to do so |  |
| `window_direction_monitor_fallback` | `bool` | `true` | If enabled, moving a window or focus over the edge of a monitor with a direction will move it to the next monitor in that direction |  |
| `allow_pin_fullscreen` | `bool` | `false` | If enabled, allow fullscreen to pinned windows, and restore their pinned status afterwards |  |
| `client_requested_fs_uses_layout_handler` | `bool` | `true` | If false, client requested FS will use default FS handler |  |
| `drag_threshold` | `int` | `0` | Movement threshold in pixels for window dragging and `click`/`drag` bind flags. `0` means disabled | [0 - ...] |
| `drag_center_window` | `bool` | `true` | Whether to center the window on the pointer, or use the initial hotspot |  |

### `xwayland`

| Option | Type | Default | Description | Limits |
| --- | --- | --- | --- | --- |
| `enabled` | `bool` | `true` | Allow running applications using X11 |  |
| `use_nearest_neighbor` | `bool` | `true` | Uses the nearest neighbor filtering for Xwayland apps, making them pixelated rather than blurry |  |
| `force_zero_scaling` | `bool` | `false` | Forces a scale of 1 on Xwayland windows on scaled displays |  |
| `create_abstract_socket` | `bool` | `false` | Create the [abstract Unix domain socket](../../extra/xwayland/#abstract-unix-domain-socket) for Xwayland connections. Xwayland restart is required for changes to take effect; Linux only |  |

### `render`

| Option | Type | Default | Description | Limits |
| --- | --- | --- | --- | --- |
| `direct_scanout` | `int` | `0` | Enables direct scanout. Direct scanout attempts to reduce lag when there is only one fullscreen application on a screen (game). It is also recommended to set this to false if the fullscreen application shows graphical glitches. `0` - disabled, `1` - enabled, `2` - auto (enabled with content type 'game') | [0 - 2] |
| `expand_undersized_textures` | `bool` | `true` | Whether to expand undersized textures along the edge, or rather stretch the entire texture |  |
| `xp_mode` | `bool` | `false` | Disables back buffer and bottom layer rendering |  |
| `ctm_animation` | `int` | `2` | Whether to enable a fade animation for CTM changes (hyprsunset). 2 means "auto" which disables them on NVIDIA | [0 - 2] |
| `cm_enabled` | `bool` | `true` | Whether the color management pipeline should be enabled or not. Requires restart |  |
| `send_content_type` | `bool` | `true` | Report content type to allow monitor profile autoswitch (may result in a black screen during the switch) |  |
| `cm_auto_hdr` | `int` | `1` | Auto-switch to HDR in fullscreen when needed. `0` - disabled, `1` - switch to `hdr`, `2` - switch to `hdredid` | [0 - 2] |
| `new_render_scheduling` | `bool` | `false` | Automatically uses triple buffering when needed, improves FPS on underpowered devices |  |
| `async_commit` | `bool` | `false` | Send DRM commits asynchronously when possible, reducing hw cursor latency |  |
| `non_shader_cm` | `int` | `2` | Enable CM without shader. `0` - disable, `1` - whenever possible, `2` - DS and passthrough only, `3` - disable and ignore CM issues. Options: [0 - 3] | [0 - 3] |
| `cm_sdr_eotf` | `string` | `"default"` | Default transfer function for displaying SDR apps. `default` - Use default value (sRGB), `gamma22` - treat unspecified as Gamma 2.2, `gamma22force` - treat unspecified and sRGB as Gamma 2.2, `srgb` - treat unspecified as sRGB. Options: `"default"`/`"gamma22"`/`"gamma22force"`/`"srgb"` |  |
| `commit_timing_enabled` | `bool` | `true` | Enable commit timing proto. Requires restart |  |
| `icc_vcgt_enabled` | `bool` | `true` | Enable sending VCGT ramps to KMS with ICC profiles |  |
| `use_shader_blur_blend` | `bool` | `false` | Use experimental blurred bg blending (glitched on rotated screens). Set to `true` if blur is missing with fp16 or `keep_unmodified_copy` |  |
| `use_fp16` | `int` | `2` | Use FP16 buffers internally. `0` - disabled, `1` - enabled, `2` - enabled in HDR mode | [0 - 2] |
| `keep_unmodified_copy` | `int` | `2` | Keep unmodified SDR frame copy for screensharing. `0` - disabled, `1` - enabled, `2` - auto (enabled in HDR with SDR modifiers). Set to 1 if screenshots are transparent | [0 - 2] |
| `non_shader_cm_interop` | `int` | `2` | `0` - external ctm (hyprsunset, etc.) is disabled in fullscreen, `1` - external ctm is enabled in fullscreen, `2` - external ctm is disabled for fullscreen photo/video/game content types | [0 - 2] |
| `fp16_sdr_tf` | `int` | `0` | Internal workbuffer transfer function for fp16 in SDR mode. 0 - monitor, 1 - linear | [0 - 1] |
| `not_shown_fifo_lock` | `int` | `0` | Control fifo locking for not shown surfaces. always - use fifo lock for any surface, ignore_unfocused - ignore render_unfocused windows, never - skip locking invisible surfaces | [0 - 2] |

### `cursor`

| Option | Type | Default | Description | Limits |
| --- | --- | --- | --- | --- |
| `invisible` | `bool` | `false` | Don't render cursors |  |
| `no_hardware_cursors` | `int` | `2` | Disables hardware cursors. `0` - use hw cursors if possible, `1` - don't use hw cursors, `2` - auto (disable when tearing) | [0 - 2] |
| `no_break_fs_vrr` | `int` | `2` | Disables scheduling new frames on cursor movement for fullscreen apps with VRR enabled to avoid framerate spikes (may require `no_hardware_cursors` set to `1`). `0` - disabled, `1` - enabled, `2` - auto (enabled with content type 'game') | [0 - 2] |
| `min_refresh_rate` | `int` | `24` | Minimum refresh rate for cursor movement when `no_break_fs_vrr` is active. Set to minimum supported refresh rate or higher | [10 - 500] |
| `hotspot_padding` | `int` | `0` | The padding, in logical px, between screen edges and the cursor | [0 - 20] |
| `inactive_timeout` | `float` | `0` | In seconds, after how many seconds of cursor's inactivity to hide it. Set to `0` for never | [0 - 20] |
| `no_warps` | `bool` | `false` | If true, will not warp the cursor in many cases (focusing, keybinds, etc.) |  |
| `persistent_warps` | `bool` | `false` | When a window is refocused, the cursor returns to its last position relative to that window, rather than to the centre |  |
| `warp_on_change_workspace` | `int` | `0` | Move the cursor to the last focused window after changing the workspace. `0` - Disabled, `1` - Enabled, `2` - Force (ignores cursor:no_warps option) | [0 - 2] |
| `warp_on_monitor_change` | `int` | `-1` | Move the cursor to the last focused window when focusing a different monitor. `-1` - follow value of `cursor:warp_on_change_workspace`, `0` - disabled, `1` - enabled, `2` - force even if `cursor:no_warps` | [-1 - 2] |
| `warp_on_toggle_special` | `int` | `0` | Move the cursor to the last focused window when toggling a special workspace. `0` - Disabled, `1` - Enabled, `2` - Force (ignores cursor:no_warps option) | [0 - 2] |
| `default_monitor` | `string` | `[[Empty]]` | The name of a default monitor for the cursor to be set to on startup (see `hyprctl monitors` for names) |  |
| `zoom_factor` | `float` | `1.0` | The factor to zoom by around the cursor. Like a magnifying glass. Minimum 1.0 (meaning no zoom) | [1 - 10] |
| `zoom_rigid` | `bool` | `false` | Whether the zoom should follow the cursor rigidly (cursor is always centered if it can be) or loosely |  |
| `zoom_disable_aa` | `bool` | `false` | Disable antialiasing when zooming, which means things will be pixelated instead of blurry |  |
| `zoom_detached_camera` | `bool` | `true` | Detach the camera from the mouse when zoomed in, only ever moving the camera to keep the mouse in view when it goes past the screen edges |  |
| `enable_hyprcursor` | `bool` | `true` | Whether to enable hyprcursor support |  |
| `hide_on_key_press` | `bool` | `false` | Hides the cursor when you press any key until the mouse is moved |  |
| `hide_on_touch` | `bool` | `true` | Hides the cursor when the last input was a touch input until a mouse input is done |  |
| `hide_on_tablet` | `bool` | `false` | Hides the cursor when the last input was a tablet input until a mouse input is done |  |
| `use_cpu_buffer` | `int` | `2` | Makes HW cursors use a CPU buffer. Required on NVIDIA to have HW cursors. `0` - disabled, `1` - enabled, `2` - auto (enabled with NVIDIA) | [0 - 2] |
| `sync_gsettings_theme` | `bool` | `true` | Sync XCursor theme with GSettings. It applies cursor-theme and cursor-size on theme load to GSettings making most CSD GTK based clients use the same XCursor theme and size |  |
| `warp_back_after_non_mouse_input` | `bool` | `false` | Warp the cursor back to where it was after using a non-mouse input to move it, and then returning back to the mouse |  |

### `ecosystem`

| Option | Type | Default | Description | Limits |
| --- | --- | --- | --- | --- |
| `no_update_news` | `bool` | `false` | Disable the popup that shows up when you update Hyprland to a new version |  |
| `no_donation_nag` | `bool` | `false` | Disable the popup that shows up twice a year encouraging to donate |  |
| `enforce_permissions` | `bool` | `false` | Whether to enable [permission control](../advanced-configuration/permissions) |  |

### `debug`

| Option | Type | Default | Description | Limits |
| --- | --- | --- | --- | --- |
| `overlay` | `bool` | `false` | Print the debug performance overlay. Disable VFR for accurate results |  |
| `damage_blink` | `bool` | `false` | (epilepsy warning!) Flash areas updated with damage tracking |  |
| `gl_debugging` | `bool` | `false` | Enables OpenGL debugging with glGetError and EGL_KHR_debug, requires a restart after changing |  |
| `disable_logs` | `bool` | `false` (repo; upstream `true`) | Disable logging to a file |  |
| `disable_time` | `bool` | `true` | Disables time logging |  |
| `damage_tracking` | `int` | `2` | Redraw only the needed bits of the display. Do **not** change. None - 0, monitor - 1, full - 2 | [0 - 2] |
| `enable_stdout_logs` | `bool` | `false` | Enables logging to stdout |  |
| `manual_crash` | `int` | `0` | Set to 1 and then back to 0 to crash Hyprland | [0 - 1] |
| `suppress_errors` | `bool` | `false` | If enabled, Hyprland will not display config file parsing errors |  |
| `disable_scale_checks` | `bool` | `false` | Disables verification of the scale factors. Will result in pixel alignment and rounding errors |  |
| `error_limit` | `int` | `5` | Limits the number of displayed config file parsing errors | [0 - 20] |
| `error_position` | `int` | `0` | Sets the position of the error bar. `0` - top, `1` bottom | [0 - 1] |
| `colored_stdout_logs` | `bool` | `true` | Enables colors in the stdout logs |  |
| `log_damage` | `bool` | `false` | Enables logging the damage |  |
| `pass` | `bool` | `false` | Enables render pass debugging |  |
| `full_cm_proto` | `bool` | `false` | Claims support for all cm proto features (requires restart) |  |
| `ds_handle_same_buffer` | `bool` | `true` | special case for direct scanout with unmodified buffer |  |
| `ds_handle_same_buffer_fifo` | `bool` | `true` | special case for direct scanout with unmodified buffer unlocks fifo |  |
| `render_solitary_wo_damage` | `bool` | `false` | render solitary window with empty damage |  |
| `vfr` | `bool` | `true` | Controls the VFR status of Hyprland. Heavily recommended to leave enabled to conserve resources |  |
| `invalidate_buffers` | `int` | `1` | Allow buffer invalidation (invalidation increases performance but produces glitches on some systems). 0 - not allowed, 1 - allowed | [0 - 1] |
| `invalidate_fp16` | `integer|boolean` | `` |  |  |

### `layout`

| Option | Type | Default | Description | Limits |
| --- | --- | --- | --- | --- |
| `single_window_aspect_ratio` | `vec2` | `{0, 0}` | Whenever only a single window is shown on a screen, add padding so that it conforms to the specified aspect ratio. A value like `4 3` on a 16:9 screen will make it a 4:3 window in the middle with padding to the sides |  |
| `single_window_aspect_ratio_tolerance` | `float` | `0.1` | Sets a tolerance for `single_window_aspect_ratio`, so that if the padding that would have been added is smaller than the specified fraction of the height or width of the screen, it will not attempt to adjust the window size | [0.0 - 1.0] |

### `dwindle`

| Option | Type | Default | Description | Limits |
| --- | --- | --- | --- | --- |
| `force_split` | `int` | `0` | 0 - split follows mouse, 1 - always split to the left (new = left or top), 2 - always split to the right (new = right or bottom) | [0 - 2] |
| `preserve_split` | `bool` | `true` (repo) | If enabled, the split (side/top) will not change regardless of what happens to the container |  |
| `smart_split` | `bool` | `false` | If enabled, allows a more precise control over the window split direction based on the cursor's position. The window is conceptually divided into four triangles, and cursor's triangle determines the split direction. This feature also turns on `preserve_split` |  |
| `smart_resizing` | `bool` | `true` | If enabled, resizing direction will be determined by the mouse's position on the window (nearest to which corner). Otherwise, it is based on the window's tiling position |  |
| `permanent_direction_override` | `bool` | `false` | If enabled, makes the preselect direction persist until either this mode is turned off, another direction is specified, or a non-direction is specified (anything other than `l`, `r`, `u`/`t`, `d`/`b`) |  |
| `special_scale_factor` | `number|boolean` | `` |  |  |
| `split_width_multiplier` | `float` | `1.0` | Specifies the auto-split width multiplier. Multiplying window size is useful on widescreen monitors where window W > H even after several splits | [0.1 - 3.0] |
| `use_active_for_splits` | `bool` | `true` | Whether to prefer the active window or the mouse position for splits |  |
| `default_split_ratio` | `float` | `1.0` | The default split ratio on window open. 1 means an even 50/50 split | [0.1 - 1.9] |
| `split_bias` | `int` | `0` | Specifies which window will receive the split ratio. 0 - directional (the top or left window), 1 - the current window | [0 - 1] |
| `precise_mouse_move` | `bool` | `false` | Dragging and dropping windows will place them more precisely, based on where your mouse is |  |

### `master`

| Option | Type | Default | Description | Limits |
| --- | --- | --- | --- | --- |
| `allow_small_split` | `bool` | `false` | Enable adding additional master windows in a horizontal split style |  |
| `special_scale_factor` | `number|boolean` | `` |  |  |
| `mfact` | `float` | `0.55` | The size as a percentage of the master window, for example `mfact = 0.70` would mean 70% of the screen will be the master window, and 30% the slave | [0 - 1] |
| `new_status` | `string` | `"master"` (repo) | `"master"` - new window becomes master, `"slave"` - new windows are added to slave stack, `"inherit"` - inherit from focused window |  |
| `new_on_top` | `bool` | `false` | Whether a newly open window should be on the top of the stack |  |
| `new_on_active` | `string` | `"none"` | `"before"`, `"after"` - place new window relative to the focused window, `"none"` - place new window according to the value of `new_on_top` |  |
| `orientation` | `string` | `"left"` | Default placement of the master area | `"left"`, `"right"`, `"top"`, `"bottom"`, `"center"` |
| `slave_count_for_center_master` | `int` | `2` | When using orientation=center, make the master window centered only when at least this many slave windows are open. (Set 0 to always center master) | [0 - 10] |
| `center_master_fallback` | `string` | `"left"` | Set fallback for center master when slaves are less than `slave_count_for_center_master` | `"left"`, `"right"`, `"top"`, `"bottom"` |
| `center_ignores_reserved` | `boolean` | `` |  |  |
| `smart_resizing` | `bool` | `true` | If enabled, resizing direction will be determined by the mouse's position on the window (nearest to which corner). Otherwise, it is based on the window's tiling position |  |
| `drop_at_cursor` | `bool` | `true` | When enabled, dragging and dropping windows will put them at the cursor position. Otherwise, when dropped at the stack side, they will go to the top/bottom of the stack depending on new_on_top |  |
| `always_keep_position` | `bool` | `false` | Whether to keep the master window in its configured position when there are no slave windows |  |
| `focus_master_on_close` | `bool` | `false` | When enabled, closing a window focuses the master window |  |

### `scrolling`

| Option | Type | Default | Description | Limits |
| --- | --- | --- | --- | --- |
| `fullscreen_on_one_column` | `bool` | `true` | When enabled, a single column on a workspace will always span the entire screen |  |
| `column_width` | `float` | `0.5` | The default width of a column | [0.1 - 1.0] |
| `focus_fit_method` | `int` | `1` | When a column is focused, what method should be used to bring it into view. 0 - center, 1 - fit, 2 - clamped_center | [0 - 2] |
| `follow_focus` | `int` | `1` | Behaviour of the scrolling tape when a window is in focus. 0: Focus doesn't cause tape move. 1: Focus may cause tape move, mouse click always moves the tape. 2: Focus may cause tape move. | [0 - 2] |
| `follow_min_visible` | `float` | `0.4` | When a window is focused, require that at least a given fraction of it is visible for focus to follow. Hard input (e.g., binds, clicks) will always follow | [0.0 - 1.0] |
| `explicit_column_widths` | `string` | `"0.333, 0.5, 0.667, 1.0"` | A comma-separated list of preconfigured widths for `colresize +conf/-conf` |  |
| `direction` | `string` | `"right"` | Direction in which new windows appear and the layout scrolls. `"left"`/`"right"`/`"down"`/`"up"` |  |
| `wrap_focus` | `bool` | `true` | When enabled, causes `hl.dsp.layout("focus l/r")` to wrap around at the beginning and end |  |
| `wrap_swapcol` | `bool` | `true` | When enabled, causes `hl.dsp.layout("swapcol l/r")` to wrap around at the beginning and end |  |

### `experimental`

| Option | Type | Default | Description | Limits |
| --- | --- | --- | --- | --- |
| `wp_cm_1_2` | `bool` | `false` | Allow wp-cm-v1 version 2 |  |

### `input_capture`

| Option | Type | Default | Description | Limits |
| --- | --- | --- | --- | --- |
| `capture_modifiers` | `bool` | `false` | If enabled, modifiers are also captured and sent to the program |  |
| `enforce_barriers` | `bool` | `true` | If enabled, throw a Wayland error when an invalid barrier is received |  |

### `quirks`

| Option | Type | Default | Description | Limits |
| --- | --- | --- | --- | --- |
| `prefer_hdr` | `int` | `0` | Report HDR mode as preferred. `0` - disabled, `1` - always, `2` - gamescope only | [0 - 1] |
| `skip_non_kms_dmabuf_formats` | `bool` | `false` | do not report dmabuf formats which cannot be imported into KMS |  |

## Keyword options

These are not `hl.config()` values; each renders the matching `hl.*` call.

| Option | Type | Default | Description |
| --- | --- | --- | --- |
| `env` | attrs of str | XDG/GTK/cursor defaults | Environment variables (`hl.env`). |
| `execOnce` | list of str | `[]` | Commands run in `hyprland.start` (`hl.exec_cmd`). |
| `exec` | list of str | `[]` | Commands run on every config load. |
| `execShutdown` | list of str | `[]` | Commands run on `hyprland.shutdown` (session exit). |
| `monitors` | list of monitor specs | `[]` | Extra `hl.monitor` rules emitted after `my.monitors` (mode, position, vrr, HDR/ICC fields, …). |
| `binds` | list of `{ keys, dispatcher, opts }` | `[]` | Extra keybinds (`hl.bind`), emitted after the built-ins so they can shadow. |
| `windowRules` | list of `{ match, rules, enabled, name }` | `[]` | Typed `hl.window_rule` entries. |
| `layerRules` | list of `{ match, rules, enabled, name }` | `[]` | Typed `hl.layer_rule` entries. |
| `workspaceRules` | list of `{ workspace, rules, enabled }` | `[]` | Typed `hl.workspace_rule` entries. |
| `animations.curves` | list of `{ name, type, points, mass, stiffness, damping }` | `[]` | Named bezier/spring curves (`hl.curve`). |
| `animations.entries` | list of `{ leaf, enabled, speed, bezier, spring, style }` | `[]` | Per-leaf animation settings (`hl.animation`); exactly one of `bezier`/`spring`. |
| `devices` | list of `{ name, rules }` | `[]` | Per-device overrides (`hl.device`). |
| `gestures` | list of `{ fingers, direction, action, luaAction, mods, scale, mode, zoom_level, workspace_name, disable_inhibit }` | `[]` | Gestures (`hl.gesture`). `luaAction` takes a raw Lua function instead of a built-in action name. |
| `permissions` | list of `{ binary, type, mode }` | `[]` | App permissions (`hl.permission`); needs `ecosystem.enforce_permissions`. |
| `plugins` | list of str | `[]` | Plugin `.so` paths (`hl.plugin.load`). |
| `submaps` | list of `{ name, reset, binds }` | `[]` | Keybind submaps (`hl.define_submap`). |
| `extraLua` | list of str | `[]` | Raw Lua statements appended last — escape hatch for anything not modelled here. |

The built-in binds, workspace startup (`core.workspaceStartup`), raw
`core.extraBinds` / `core.extraWindowRules` and per-class opacity overrides
(`appearance.overrides`) still exist and are emitted alongside these options.


## Regenerating after a Hyprland upgrade

`spec.nix` mirrors the `HL.ConfigOpt` stubs that ship in the Hyprland package
(`share/hypr/stubs/hl.meta.lua`); the descriptions, types and defaults come
from the wiki pages linked above. After bumping Hyprland:

1. Diff the new `hl.meta.lua` against `spec.nix` — new keys need a leaf, removed
   keys must be dropped, changed Lua types need the matching `type` string.
2. Check the wiki table for new/changed defaults and copy them in; keep the
   repo overrides marked in the table above.
3. Regenerate the Options table from `spec.nix` and verify the result with
   `Hyprland --verify-config --config <generated hyprland.lua>` before merging.
