# Hyprland `hl.config()` surface — one option per documented Hyprland setting.
#
# Generated from the Hyprland wiki (Config options + Dwindle/Master/Scrolling
# layout pages, 2026-11-24) and filtered against the `hl.meta.lua` stubs shipped
# with Hyprland 0.57.2, so only options this Hyprland understands are declared.
#
# Each leaf is `{ type, default, description, limits }`:
#   - `default`  the repo default (Hyprland's own default unless a comment says
#                otherwise); every option can be overridden per host.
#   - `limits`   Hyprland's documented accepted range/values.
#
# `type` is one of: bool, int, float, str, gap, gradient, vec2,
# intOrStr — with a `nullable:` prefix meaning the value may be `null`
# (unset), in which case nothing is emitted and Hyprland's built-in value wins.
{
  # ---- repo-specific defaults (differ from upstream Hyprland) --------------
  # general.col.*, decoration.shadow.color and the bounds in this file are set
  # from the palette in ../appearance/theme.nix with lib.mkDefault.

  general = {
    border_size = {
      type = "int";
      default = 2;
      description = "Size of the border around windows";
      limits = "[0 - 20]";
    };
    gaps_in = {
      type = "gap";
      default = 5;
      description = "Gaps between windows";
    };
    gaps_out = {
      type = "gap";
      default = 20;
      description = "Gaps between windows and monitor edges";
    };
    float_gaps = {
      type = "gap";
      default = 0;
      description = "Gaps between windows and monitor edges for floating windows `-1` means default.";
    };
    gaps_workspaces = {
      type = "int";
      default = 0;
      description = "Gaps between workspaces. Stacks with gaps_out";
      limits = "[0 - 100]";
    };
    col = {
      inactive_border = {
        type = "gradient";
        default = "0xff444444";
        description = "Border color for inactive windows";
      };
      active_border = {
        type = "gradient";
        default = "0xffffffff";
        description = "Border color for the active window";
      };
      nogroup_border = {
        type = "gradient";
        default = "0xffffaaff";
        description = "Border color for inactive windows that cannot be added to a group";
      };
      nogroup_border_active = {
        type = "gradient";
        default = "0xffff00ff";
        description = "Border color for the active window that cannot be added to a group";
      };
    };
    layout = {
      type = "str";
      default = "dwindle";
      description = "Which layout to use. Options: `\"dwindle\"`/`\"master\"`/`\"scrolling\"`/`\"monocle\"`";
    };
    no_focus_fallback = {
      type = "bool";
      default = false;
      description = "If true, will not fall back to the next available window when moving focus in a direction where no window was found";
    };
    resize_on_border = {
      type = "bool";
      default = true;
      description = "Enables resizing windows by clicking and dragging on borders and gaps";
    };
    extend_border_grab_area = {
      type = "int";
      default = 15;
      description = "Extends the area around the border where you can click and drag on, only used when `general.resize_on_border` is on";
      limits = "[0 - 100]";
    };
    hover_icon_on_border = {
      type = "bool";
      default = true;
      description = "Show a cursor icon when hovering over borders, only used when `general.resize_on_border` is on";
    };
    allow_tearing = {
      type = "bool";
      default = false;
      description = "Master switch for allowing tearing to occur. See the [Tearing page](../../extra/tearing)";
    };
    resize_corner = {
      type = "int";
      default = 0;
      description = "Force floating windows to use a specific corner when being resized (1-4 going clockwise from top left, 0 to disable)";
      limits = "[0 - 4]";
    };
    snap = {
      enabled = {
        type = "bool";
        default = false;
        description = "Enable snapping for floating windows";
      };
      window_gap = {
        type = "int";
        default = 10;
        description = "Minimum gap in pixels between windows before snapping";
        limits = "[0 - 100]";
      };
      monitor_gap = {
        type = "int";
        default = 10;
        description = "Minimum gap in pixels between window and monitor edges before snapping";
        limits = "[0 - 100]";
      };
      border_overlap = {
        type = "bool";
        default = false;
        description = "If enabled, windows snap such that only one border's worth of space is between them";
      };
      respect_gaps = {
        type = "bool";
        default = false;
        description = "If enabled, snapping will respect gaps between windows (set in general:gaps_in)";
      };
    };
    modal_parent_blocking = {
      type = "bool";
      default = true;
      description = "Whether parent windows of modals will be interactive";
    };
    locale = {
      type = "nullable:str";
      default = null;
      description = "Overrides the system locale, e.g. `\"en_US\"`, `\"es\"`";
    };
  };
  decoration = {
    rounding = {
      type = "rounding";
      default = 8;
      description = "Rounded corners' radius (in layout px)";
      limits = "[0 - 100]";
    };
    rounding_power = {
      type = "float";
      default = 2.0;
      description = "Adjusts the curve used for rounding corners, larger is smoother, 1.0 is a triangular corner, 2.0 is a circle, 4.0 is a squircle";
      limits = "[1.0 - 10.0]";
    };
    active_opacity = {
      type = "float";
      default = 1.0;
      description = "Opacity of active windows";
      limits = "[0.0 - 1.0]";
    };
    inactive_opacity = {
      type = "float";
      default = 1.0;
      description = "Opacity of inactive windows";
      limits = "[0.0 - 1.0]";
    };
    fullscreen_opacity = {
      type = "float";
      default = 1.0;
      description = "Opacity of fullscreen windows";
      limits = "[0.0 - 1.0]";
    };
    shadow = {
      enabled = {
        type = "bool";
        default = false;
        description = "Enable drop shadows on windows";
      };
      range = {
        type = "int";
        default = 12;
        description = "Shadow range (size) in pixels";
        limits = "[0 - 100]";
      };
      render_power = {
        type = "int";
        default = 3;
        description = "In what power to render the falloff. More power, the faster the falloff";
        limits = "[1 - 4]";
      };
      sharp = {
        type = "bool";
        default = false;
        description = "If enabled, will make the shadows sharp, akin to an infinite render power";
      };
      color = {
        type = "gradient";
        default = "0xee1a1a1a";
        description = "Active window shadow's color. Alpha dictates the opacity";
      };
      color_inactive = {
        type = "nullable:gradient";
        default = null;
        description = "Inactive window shadow's color. If not set, will fall back to `color`";
      };
      offset = {
        type = "vec2";
        default = { x = 0; y = 0; };
        description = "Shadow's rendering offset";
      };
      scale = {
        type = "float";
        default = 1.0;
        description = "Shadow's scale";
        limits = "[0.05 - 2.0]";
      };
    };
    glow = {
      enabled = {
        type = "bool";
        default = false;
        description = "Enable inner glow on windows";
      };
      range = {
        type = "int";
        default = 10;
        description = "Glow range (size) in pixels";
        limits = "[0 - 100]";
      };
      render_power = {
        type = "int";
        default = 3;
        description = "In what power to render the falloff. More power, the faster the falloff";
        limits = "[1 - 4]";
      };
      color = {
        type = "gradient";
        default = "0xee1a1a1a";
        description = "Active window glow's color. Alpha dictates opacity";
      };
      color_inactive = {
        type = "nullable:gradient";
        default = null;
        description = "Inactive window glow's color. If not set, will fall back to `color`";
      };
    };
    dim_modal = {
      type = "bool";
      default = true;
      description = "Enables dimming of parents of modal windows";
    };
    dim_inactive = {
      type = "bool";
      default = false;
      description = "Enables dimming of inactive windows";
    };
    dim_strength = {
      type = "float";
      default = 0.5;
      description = "How much inactive windows should be dimmed";
      limits = "[0.0 - 1.0]";
    };
    dim_special = {
      type = "float";
      default = 0.2;
      description = "How much to dim the rest of the screen by when a special workspace is open. [0.0 - 1.0]";
    };
    dim_around = {
      type = "float";
      default = 0.4;
      description = "How much the `dim_around` window rule should dim by";
      limits = "[0.0 - 1.0]";
    };
    screen_shader = {
      type = "nullable:str";
      default = null;
      description = "A path to a custom shader to be applied at the end of rendering. See `examples/screenShader.frag` for an example";
    };
    border_part_of_window = {
      type = "bool";
      default = true;
      description = "Whether the window border should be a part of the window";
    };
    blur = {
      enabled = {
        type = "bool";
        default = false;
        description = "Enable kawase window background blur";
      };
      variant = {
        type = "intOrStr";
        default = "kawase";
        description = "Blur pattern variant. May significantly increase GPU and CPU usage";
        limits = "[see below](#blur-variants)";
      };
      size = {
        type = "int";
        default = 6;
        description = "Blur size (distance)";
      };
      passes = {
        type = "int";
        default = 2;
        description = "The amount of passes to perform";
        limits = "[0 - 10]";
      };
      ignore_opacity = {
        type = "bool";
        default = true;
        description = "Make the blur layer ignore the opacity of the window";
      };
      new_optimizations = {
        type = "bool";
        default = true;
        description = "Whether to enable further optimizations to the blur. Recommended to leave on, as it will massively improve performance";
      };
      xray = {
        type = "bool";
        default = false;
        description = "If enabled, floating windows will ignore tiled windows in their blur. Will reduce overhead on floating blur significantly. Disabled if `new_optimizations = false`";
      };
      proportional = {
        type = "bool";
        default = false;
        description = "If enabled, blur strength will be proportional to pixel opacity. Requires `render:use_shader_blur_blend`";
      };
      noise = {
        type = "float";
        default = 0.0117;
        description = "How much noise to apply";
        limits = "[0.0 - 1.0]";
      };
      contrast = {
        type = "float";
        default = 0.8916;
        description = "Contrast modulation for blur";
        limits = "[0.0 - 2.0]";
      };
      brightness = {
        type = "float";
        default = 1.0;
        description = "Brightness modulation for blur";
        limits = "[0.0 - 2.0]";
      };
      vibrancy = {
        type = "float";
        default = 0.1696;
        description = "Increase saturation of blurred colors";
        limits = "[0.0 - 1.0]";
      };
      vibrancy_darkness = {
        type = "float";
        default = 0.0;
        description = "How strong the effect of `vibrancy` is on dark areas";
        limits = "[0.0 - 1.0]";
      };
      special = {
        type = "bool";
        default = false;
        description = "Whether to blur behind the special workspace (note: expensive)";
      };
      popups = {
        type = "bool";
        default = false;
        description = "Whether to blur popups, e.g. `right-click menus`";
      };
      popups_ignorealpha = {
        type = "float";
        default = 0.2;
        description = "Works like ignore_alpha in layer rules. If pixel opacity is below the set value, will not blur";
        limits = "[0.0 - 1.0]";
      };
      input_methods = {
        type = "bool";
        default = false;
        description = "Whether to blur input methods, e.g. `fcitx5`";
      };
      input_methods_ignorealpha = {
        type = "float";
        default = 0.2;
        description = "Works like ignore_alpha in layer rules. If pixel opacity is below the set value, will not blur";
        limits = "[0.0 - 1.0]";
      };
      glass = {
        refraction = {
          type = "float";
          default = 20.0;
          description = "Maximum refraction displacement for glass blur types in pixels";
          limits = "[0.0 - 20.0]";
        };
        size = {
          type = "float";
          default = 40.0;
          description = "Pattern size for glass blur types in pixels";
          limits = "[4.0 - 512.0]";
        };
        roughness = {
          type = "float";
          default = 1.0;
          description = "Strength of the glass relief shading";
          limits = "[0.0 - 1.0]";
        };
      };
      acrylic = {
        refraction = {
          type = "float";
          default = 24.0;
          description = "Maximum acrylic lens displacement in pixels";
          limits = "[0.0 - 48.0]";
        };
        bulb = {
          type = "float";
          default = 48.0;
          description = "Width of the curved acrylic edge in pixels";
          limits = "[4.0 - 256.0]";
        };
        clarity = {
          type = "float";
          default = 0.82;
          description = "Amount of sharp backdrop passing through the acrylic surface";
          limits = "[0.0 - 1.0]";
        };
        aberration = {
          type = "float";
          default = 0.025;
          description = "Relative chromatic separation in the acrylic lens";
          limits = "[0.0 - 0.25]";
        };
        tint = {
          type = "str";
          default = "0x14EEF5FF";
          description = "Acrylic tint color. Alpha channel controls optical absorption";
        };
      };
      drops = {
        speed = {
          type = "float";
          default = 3.0;
          description = "Animation speed. 0 disables the animation";
          limits = "[0.0 - 10.0]";
        };
      };
      heat_shimmer = {
        speed = {
          type = "float";
          default = 1.0;
          description = "Animation speed. 0 disables the animation";
          limits = "[0.0 - 10.0]";
        };
      };
      aurora = {
        speed = {
          type = "float";
          default = 1.0;
          description = "Animation speed. 0 freezes the animation";
          limits = "[0.0 - 10.0]";
        };
        intensity = {
          type = "float";
          default = 0.35;
          description = "Strength of the aurora color contribution";
          limits = "[0.0 - 1.0]";
        };
        color1 = {
          type = "str";
          default = "0x29F0A0FF";
          description = "First aurora curtain color. Alpha controls its contribution";
        };
        color2 = {
          type = "str";
          default = "0x7A4DFFFF";
          description = "Second aurora curtain color. Alpha controls its contribution";
        };
      };
      haze = {
        intensity = {
          type = "float";
          default = 0.35;
          description = "Strength of the haze pearlescent sheen";
          limits = "[0.0 - 1.0]";
        };
        iridescence = {
          type = "float";
          default = 0.7;
          description = "Strength of the haze pearlescent color shift";
          limits = "[0.0 - 1.0]";
        };
      };
      ripple = {
        strength = {
          type = "float";
          default = 30.0;
          description = "Maximum refraction displacement in pixels";
          limits = "[0.0 - 32.0]";
        };
        radius = {
          type = "float";
          default = 400.0;
          description = "Maximum radius in pixels";
          limits = "[1.0 - 1000.0]";
        };
        width = {
          type = "float";
          default = 32.0;
          description = "Width of waves in pixels";
          limits = "[1.0 - 200.0]";
        };
        duration = {
          type = "float";
          default = 0.45;
          description = "Duration in seconds";
          limits = "[0.05 - 5.0]";
        };
      };
      water = {
        strength = {
          type = "float";
          default = 32.0;
          description = "Maximum refraction displacement and injection strength in pixels";
          limits = "[0.0 - 32.0]";
        };
        radius = {
          type = "float";
          default = 20.0;
          description = "Pointer radius in pixels";
          limits = "[1.0 - 1000.0]";
        };
        speed = {
          type = "float";
          default = 0.76;
          description = "Propagation speed";
          limits = "[0.0 - 10.0]";
        };
        damping = {
          type = "float";
          default = 0.95;
          description = "Decay damping";
          limits = "[0.0 - 1.0]";
        };
        duration = {
          type = "float";
          default = 12.0;
          description = "Maximum duration in seconds";
          limits = "[0.5 - 60.0]";
        };
      };
      fluid_jar = {
        color = {
          type = "str";
          default = "0xCC3399FF";
          description = "Fluid color";
        };
        speed = {
          type = "float";
          default = 3.7;
          description = "Animation speed";
          limits = "[0.0 - 10.0]";
        };
        fill_amount = {
          type = "float";
          default = 0.5;
          description = "Fill level for of the fluid";
          limits = "[0.0 - 1.0]";
        };
        mass = {
          type = "float";
          default = 1.4;
          description = "Fluid's Inertial mass";
          limits = "[0.1 - 10.0]";
        };
        precision = {
          type = "float";
          default = 2.0;
          description = "Fluid simulation precision multiplier. 2x is a good compromise. 4x is expensive. 8x is extreme and unnecessary";
          limits = "[0.5 - 8.0]";
        };
        turbulence = {
          type = "float";
          default = 1.2;
          description = "Interior fluid turbulence multiplier";
          limits = "[0.0 - 5.0]";
        };
        distortion = {
          type = "float";
          default = 8.0;
          description = "Fluid refraction distortion multiplier";
          limits = "[0.0 - 10.0]";
        };
      };
    };
    motion_blur = {
      enabled = {
        type = "bool";
        default = false;
        description = "enable motion blur on moving/resizing windows";
      };
      samples = {
        type = "int";
        default = 7;
        description = "The amount of samples to render. More will mean clearer blur, at the cost of more compute";
        limits = "[1 - 64]";
      };
    };
    wobble = {
      enabled = {
        type = "bool";
        default = false;
        description = "enable wobble on moving/resizing windows";
      };
      mesh = {
        type = "int";
        default = 12;
        description = "amount of wobble mesh vertices per edge";
        limits = "[2 - 32]";
      };
      stiffness = {
        type = "float";
        default = 200.0;
        description = "spring stiffness for wobble deformation";
        limits = "[0.0001 - 1000]";
      };
      damping = {
        type = "float";
        default = 12.0;
        description = "spring damping for wobble deformation";
        limits = "[0 - 1000]";
      };
      mass = {
        type = "float";
        default = 1.0;
        description = "spring mass for wobble deformation";
        limits = "[0.0001 - 1000]";
      };
      intensity = {
        type = "float";
        default = 0.2;
        description = "wobble deformation impulse multiplier";
        limits = "[0 - 2]";
      };
      value_epsilon = {
        type = "float";
        default = 0.25;
        description = "position epsilon below which wobble is considered stable";
        limits = "[0 - 100]";
      };
      velocity_epsilon = {
        type = "float";
        default = 2.0;
        description = "velocity epsilon below which wobble is considered stable";
        limits = "[0 - 1000]";
      };
    };
  };
  animations = {
    enabled = {
      type = "bool";
      default = true;
      description = "Enable animations";
    };
    workspace_wraparound = {
      type = "bool";
      default = false;
      description = "Enable workspace wraparound, causing directional workspace animations to animate as if the first and last workspaces were adjacent";
    };
  };
  input = {
    kb_model = {
      type = "nullable:str";
      default = null;
      description = "Appropriate XKB keymap parameter. See the note [below](#xkb-keymap-params)";
    };
    kb_layout = {
      type = "str";
      default = "us";
      description = "Appropriate XKB keymap parameter";
    };
    kb_variant = {
      type = "nullable:str";
      default = null;
      description = "Appropriate XKB keymap parameter";
    };
    kb_options = {
      type = "nullable:str";
      default = null;
      description = "Appropriate XKB keymap parameter";
    };
    kb_rules = {
      type = "nullable:str";
      default = null;
      description = "Appropriate XKB keymap parameter";
    };
    kb_file = {
      type = "nullable:str";
      default = null;
      description = "If you prefer, you can use a path to your custom .xkb file";
    };
    numlock_by_default = {
      type = "bool";
      default = false;
      description = "Enable numlock by default";
    };
    resolve_binds_by_sym = {
      type = "bool";
      default = false;
      description = "Determines how keybinds act when multiple layouts are used. If false, keybinds will always act as if the first specified layout is active. If true, keybinds specified by symbols are activated when you type the respective symbol with the current layout";
    };
    repeat_rate = {
      type = "int";
      default = 25;
      description = "The repeat rate for held-down keys, in repeats per second";
      limits = "[0 - 200]";
    };
    repeat_delay = {
      type = "int";
      default = 600;
      description = "Delay before a held-down key is repeated, in milliseconds";
      limits = "[0 - 2000]";
    };
    sensitivity = {
      type = "float";
      default = 0.0;
      description = "Sets the mouse input sensitivity. Additional info: [libinput#pointer-acceleration](https://wayland.freedesktop.org/libinput/doc/latest/pointer-acceleration.html#pointer-acceleration)";
      limits = "[-1.0 - 1.0]";
    };
    accel_profile = {
      type = "nullable:str";
      default = null;
      description = "Sets the cursor acceleration profile. See the note [below](#accel-profile). Leave empty to use `libinput`'s default mode for your input device. [libinput#pointer-acceleration](https://wayland.freedesktop.org/libinput/doc/latest/pointer-acceleration.html#pointer-acceleration). Options: `\"adaptive\"`/`\"flat\"`/`\"custom\"`";
    };
    force_no_accel = {
      type = "bool";
      default = false;
      description = "Force no cursor acceleration. This bypasses most of your pointer settings to get as raw of a signal as possible. **Enabling this is not recommended due to potential cursor desynchronization.**";
    };
    rotation = {
      type = "int";
      default = 0;
      description = "Sets the rotation of a device in degrees clockwise off the logical neutral position";
      limits = "[0 - 359]";
    };
    left_handed = {
      type = "bool";
      default = false;
      description = "Switches RMB and LMB";
    };
    scroll_points = {
      type = "nullable:str";
      default = null;
      description = "Sets the scroll acceleration profile, when `accel_profile` is set to `\"custom\"`. Has to be in the form `\"<step> <points>\"`. Leave empty to have a flat scroll curve";
    };
    scroll_method = {
      type = "nullable:str";
      default = null;
      description = "Sets the scroll method. Additional info: [libinput#scrolling](https://wayland.freedesktop.org/libinput/doc/latest/scrolling.html). Options: `\"2fg\"`/`\"edge\"`/`\"on_button_down\"`/`\"no_scroll\"` (2fg - 2 fingers)";
    };
    scroll_button = {
      type = "int";
      default = 0;
      description = "Sets the scroll button. Check `wev` for the ID. `0` means default";
      limits = "[0 - 300]";
    };
    scroll_button_lock = {
      type = "bool";
      default = false;
      description = "If the scroll button lock is enabled, the button does not need to be held down. Pressing and releasing the button toggles the button lock, which logically holds the button down or releases it. While the button is logically held down, motion events are converted to scroll events";
    };
    scroll_factor = {
      type = "float";
      default = 1.0;
      description = "Multiplier added to scroll movement for external mice. Note that there is a separate setting for [touchpad scroll_factor](#touchpad)";
      limits = "[0 - 100]";
    };
    natural_scroll = {
      type = "bool";
      default = false;
      description = "Inverts scrolling direction. When enabled, scrolling moves content directly, rather than manipulating a scrollbar";
    };
    follow_mouse = {
      type = "int";
      default = 1;
      description = "Specify if and how cursor movement should affect window focus. See the note [below](#follow-mouse)";
      limits = "[0 - 3]";
    };
    follow_mouse_threshold = {
      type = "float";
      default = 0.0;
      description = "The smallest distance in logical pixels the mouse needs to travel for the window under it to get focused. Works only with `follow_mouse` set to`1`";
    };
    swallow_focus_click = {
      type = "bool";
      default = false;
      description = "If enabled, the first click on unfocused window will focus it without forwarding the click action. Only relevant when mouse focus is detached, e.g. `input.follow_mouse` is `0` or `2`";
    };
    focus_on_close = {
      type = "int";
      default = 0;
      description = "Controls the window focus behavior when a window is closed. When set to `0`, focus will shift to the next window candidate. When set to `1`, focus will shift to the window under the cursor. When set to `2`, focus will shift to the most recently used/active window";
      limits = "[0 - 2]";
    };
    mouse_refocus = {
      type = "bool";
      default = true;
      description = "If enabled, mouse focus will switch to the hovered window when the pointer crosses a window boundary. Works only with `follow_mouse` set to `1`";
    };
    float_switch_override_focus = {
      type = "int";
      default = 1;
      description = "If `1`/`2` focus will change to the window under the cursor when changing from tiled-to-floating and vice versa. If `2`, focus will also follow mouse on float-to-float switches. `0` means disabled";
      limits = "[0 - 2]";
    };
    special_fallthrough = {
      type = "bool";
      default = false;
      description = "If enabled, having only floating windows in the special workspace will not block focusing windows in the regular workspace";
    };
    off_window_axis_events = {
      type = "int";
      default = 1;
      description = "Handles axis events around (gaps/border for tiled, dragarea/border for floated) a focused window. `0` ignores axis events `1` sends out-of-bound coordinates `2` fakes pointer coordinates to the closest point inside the window `3` warps the cursor to the closest point inside the window";
      limits = "[0 - 3]";
    };
    emulate_discrete_scroll = {
      type = "int";
      default = 1;
      description = "Emulates discrete scrolling from high resolution scrolling events. `0` disables it, `1` enables handling of non-standard events only, and `2` force enables all scroll wheel events to be handled";
      limits = "[0 - 2]";
    };
    follow_mouse_shrink = {
      type = "int";
      default = 0;
      description = "Shrinks the inactive window hitboxes used for focus detection by the specified number of pixels. This creates a dead zone in gaps between windows where moving the cursor will not change focus. Works only with `follow_mouse` set to `1`";
      limits = "[0 - 300]";
    };
    touchpad = {
      disable_while_typing = {
        type = "bool";
        default = true;
        description = "Disable the touchpad while typing";
      };
      natural_scroll = {
        type = "bool";
        default = true;
        description = "Inverts scrolling direction. When enabled, scrolling moves content directly, rather than manipulating a scrollbar";
      };
      scroll_factor = {
        type = "float";
        default = 1.0;
        description = "Multiplier applied to the amount of scroll movement";
        limits = "[0.0 - 100]";
      };
      middle_button_emulation = {
        type = "bool";
        default = false;
        description = "Sending LMB and RMB simultaneously will be interpreted as a middle click. This disables any touchpad area that would normally send a middle click based on location. Additional info: [libinput#middle-button-emulation](https://wayland.freedesktop.org/libinput/doc/latest/middle-button-emulation.html)";
      };
      tap_button_map = {
        type = "nullable:str";
        default = null;
        description = "Sets the tap button mapping for touchpad button emulation. When empty, defaults to `\"lrm\"`. L - Left, M - Middle, R - Right";
        limits = "\"lrm\"/\"lmr\"";
      };
      clickfinger_behavior = {
        type = "bool";
        default = false;
        description = "Button presses with 1, 2, or 3 fingers will be mapped to LMB, RMB, and MMB respectively. This disables interpretation of clicks based on location on the touchpad. Additional info: [libinput#clickfinger-behavior](https://wayland.freedesktop.org/libinput/doc/latest/clickpad-softbuttons.html#clickfinger-behavior)";
      };
      tap_to_click = {
        type = "bool";
        default = true;
        description = "Tapping on the touchpad with 1, 2, or 3 fingers will send LMB, RMB, and MMB respectively";
      };
      drag_lock = {
        type = "int";
        default = 1;
        description = "When enabled, lifting the finger off while dragging will not drop the dragged item. 0 - disabled, 1 - enabled with timeout, 2 - enabled sticky. Additional info: [libinput#tap-and-drag](https://wayland.freedesktop.org/libinput/doc/latest/tapping.html#tap-and-drag)";
        limits = "[0 - 2]";
      };
      tap_and_drag = {
        type = "bool";
        default = true;
        description = "Sets the tap and drag mode for the touchpad";
      };
      flip_x = {
        type = "bool";
        default = false;
        description = "Inverts the horizontal movement of the touchpad";
      };
      flip_y = {
        type = "bool";
        default = false;
        description = "Inverts the vertical movement of the touchpad";
      };
      drag_3fg = {
        type = "int";
        default = 0;
        description = "Enables three finger drag. Additional info: [libinput#drag-3fg](https://wayland.freedesktop.org/libinput/doc/latest/drag-3fg.html)";
        limits = "[0 - 2]";
      };
    };
    touchdevice = {
      transform = {
        type = "int";
        default = 0;
        description = "Transform the input from touchdevices. The possible transformations are the same as [those of the monitors](../monitors/positioning#rotation)";
        limits = "[0 - 6]";
      };
      output = {
        type = "nullable:str";
        default = null;
        description = "The monitor to bind touch devices. The default is auto-detection. To stop auto-detection, use an empty string";
      };
      enabled = {
        type = "bool";
        default = true;
        description = "Whether input is enabled for touch devices";
      };
    };
    virtualkeyboard = {
      share_states = {
        type = "int";
        default = 2;
        description = "Unify key down states and modifier states with other keyboards. 0 - no, 1 - yes, 2 - yes unless IME client";
        limits = "[0 - 2]";
      };
      release_pressed_on_close = {
        type = "bool";
        default = false;
        description = "Release all pressed keys by virtual keyboard on close";
      };
    };
    tablet = {
      enabled = {
        type = "bool";
        default = true;
        description = "Whether input is enabled for tablets";
      };
      transform = {
        type = "int";
        default = 0;
        description = "Transform the input from tablets. The possible transformations are the same as [those of the monitors](../monitors/positioning#rotation)";
        limits = "[0 - 6]";
      };
      output = {
        type = "nullable:str";
        default = null;
        description = "The monitor to bind tablets. Can be `\"current\"` or a monitor name. Leave empty to map across all monitors";
      };
      region_position = {
        type = "vec2";
        default = { x = 0; y = 0; };
        description = "Position of the mapped region in monitor layout relative to the top left corner of the bound monitor or all monitors";
        limits = "[-100000 - 100000]";
      };
      absolute_region_position = {
        type = "bool";
        default = false;
        description = "Whether to treat the `region_position` as an absolute position in monitor layout. Only applies when `output` is empty";
      };
      region_size = {
        type = "nullable:vec2";
        default = null;
        description = "Size of the mapped region. When this variable is set, tablet input will be mapped to the region. `{0, 0}` or invalid size means unset";
        limits = "[1 - 100000]";
      };
      relative_input = {
        type = "bool";
        default = false;
        description = "Whether the input should be relative";
      };
      left_handed = {
        type = "bool";
        default = false;
        description = "If enabled, the tablet will be rotated 180 degrees";
      };
      active_area_size = {
        type = "vec2";
        default = { x = 0; y = 0; };
        description = "Size of tablet's active area in mm";
        limits = "[0 - 5000]";
      };
      active_area_position = {
        type = "vec2";
        default = { x = 0; y = 0; };
        description = "Position of the active area in mm";
        limits = "[0 - 5000]";
      };
    };
    tablettool = {
      eraser_button_mode = {
        type = "int";
        default = 0;
        description = "Change the eraser button behavior on the tool. When set to `0`, use the default hardware behavior of the tool. When set to `1`, the eraser button on the tool sends a button event instead";
        limits = "[0 - 6]";
      };
      eraser_button_override = {
        type = "int";
        default = 0;
        description = "Set a button to be button event when eraser_button_mode is set to `1`. Must be a valid button (e.g., BTN_STYLUS) excluding fake buttons (e.g., BTN_TOOL_\\*) and keys (KEY_\\*). Check `wev` for the ID. `0` means default";
        limits = "[0 - ...]";
      };
      pressure_range_min = {
        type = "float";
        default = -1.0;
        description = "Set the minimum pressure range for the tool. Negative values mean it will use device defaults. Usually it is `0.0`";
        limits = "[-1.0 - 1.0]";
      };
      pressure_range_max = {
        type = "float";
        default = -1.0;
        description = "Set the maximum pressure range for the tool. Negative values mean it will use device defaults. Usually it is `1.0`";
        limits = "[-1.0 - 1.0]";
      };
    };
  };
  gestures = {
    workspace_swipe_distance = {
      type = "int";
      default = 300;
      description = "In pixels, the distance of the touchpad gesture";
      limits = "[0 - 2000]";
    };
    workspace_swipe_touch = {
      type = "bool";
      default = false;
      description = "Enable workspace swiping from the edge of a touchscreen";
    };
    workspace_swipe_invert = {
      type = "bool";
      default = true;
      description = "Invert the swipe direction (touchpad only)";
    };
    workspace_swipe_touch_invert = {
      type = "bool";
      default = false;
      description = "Invert the swipe direction (touchscreen only)";
    };
    workspace_swipe_min_speed_to_force = {
      type = "int";
      default = 30;
      description = "Minimum speed in pixels per timepoint to force the change ignoring `cancel_ratio`. `0` means disabled";
      limits = "[0 - 200]";
    };
    workspace_swipe_cancel_ratio = {
      type = "float";
      default = 0.5;
      description = "How much the swipe has to proceed in order to commence it. Example, when set to `0.7`: if more than 70% of the distance is covered, switch; else, cancel the gesture";
      limits = "[0.0 - 1.0]";
    };
    workspace_swipe_create_new = {
      type = "bool";
      default = true;
      description = "Whether a swipe right on the last workspace should create a new one";
    };
    workspace_swipe_direction_lock = {
      type = "bool";
      default = true;
      description = "If enabled, switching direction will be locked when you swipe past the `direction_lock_threshold` (touchpad only)";
    };
    workspace_swipe_direction_lock_threshold = {
      type = "int";
      default = 10;
      description = "In pixels, the distance to swipe before direction lock activates (touchpad only)";
      limits = "[0 - 200]";
    };
    workspace_swipe_forever = {
      type = "bool";
      default = false;
      description = "If enabled, swiping will not clamp at the neighboring workspaces but continue to the further ones";
    };
    workspace_swipe_use_r = {
      type = "bool";
      default = false;
      description = "If enabled, swiping will use the `r` prefix instead of the `m` prefix for finding workspaces";
    };
    close_max_timeout = {
      type = "int";
      default = 1000;
      description = "The timeout for a window to close when using a 1:1 gesture, in ms";
      limits = "[10 - 2000]";
    };
    scrolling = {
      move_snap_to_grid = {
        type = "bool";
        default = true;
        description = "When releasing the scroll move gesture, whether it should try to snap to the grid";
      };
      move_snap_cursor = {
        type = "bool";
        default = true;
        description = "When releasing the scroll move gesture, whether it should snap the cursor to the newly focused window";
      };
    };
  };
  group = {
    insert_after_current = {
      type = "bool";
      default = true;
      description = "Whether new windows in a group spawn after current or at group tail";
    };
    focus_removed_window = {
      type = "bool";
      default = true;
      description = "Whether Hyprland should focus on the window that has just been moved out of the group";
    };
    merge_groups_on_drag = {
      type = "bool";
      default = true;
      description = "Whether window groups can be dragged into other groups";
    };
    merge_groups_on_groupbar = {
      type = "bool";
      default = true;
      description = "Whether one group will be merged with another when dragged into its groupbar. *Note: enabling this option only works when combined with `drag_into_group = 2` and `merge_groups_on_drag = true`*";
    };
    col = {
      border_active = {
        type = "gradient";
        default = "0x66ffff00";
        description = "Active group border color. Has additional `whole_monitor? = bool` parameter in the gradient";
      };
      border_inactive = {
        type = "gradient";
        default = "0x66777700";
        description = "Inactive group border color. Has additional `whole_monitor? = bool` parameter in the gradient";
      };
      border_locked_inactive = {
        type = "gradient";
        default = "0x66775500";
        description = "Inactive locked group border color. Has additional `whole_monitor? = bool` parameter in the gradient";
      };
      border_locked_active = {
        type = "gradient";
        default = "0x66ff5500";
        description = "Active locked group border color. Has additional `whole_monitor? = bool` parameter in the gradient";
      };
    };
    auto_group = {
      type = "bool";
      default = true;
      description = "Whether new windows will be automatically grouped into the focused unlocked group. *Note: if you want to disable auto_group only for specific windows, use [the \"group barred\" window rule](../rules/window-rules/#group-window-rule-options) instead*";
    };
    drag_into_group = {
      type = "int";
      default = 1;
      description = "Whether dragging a window into an unlocked group will merge them. `0` - disabled, `1` - enabled, `2` - only when dragging into a groupbar";
      limits = "[0 - 2]";
    };
    merge_floated_into_tiled_on_groupbar = {
      type = "bool";
      default = false;
      description = "Whether dragging a floating window into a tiled window groupbar will merge them";
    };
    group_on_movetoworkspace = {
      type = "bool";
      default = false;
      description = "Whether using hl.dsp.window.move({ workspace }) will merge the window into the workspace's solitary unlocked group";
    };
    groupbar = {
      enabled = {
        type = "bool";
        default = true;
        description = "Enables groupbars";
      };
      disable_when_only = {
        type = "bool";
        default = false;
        description = "Disable groupbar if it contains a single window";
      };
      font_family = {
        type = "nullable:str";
        default = null;
        description = "Font used to display groupbar titles, use `misc.font_family` if not specified";
      };
      font_weight_active = {
        type = "intOrStr";
        default = "normal";
        description = "Font weight of active groupbar title";
      };
      font_weight_inactive = {
        type = "intOrStr";
        default = "normal";
        description = "Font weight of inactive groupbar title";
      };
      font_size = {
        type = "int";
        default = 8;
        description = "Font size of groupbar title";
        limits = "[2 - 64]";
      };
      gradients = {
        type = "bool";
        default = false;
        description = "Enables gradients";
      };
      height = {
        type = "int";
        default = 14;
        description = "Height of the groupbar";
        limits = "[0 - 64]";
      };
      indicator_gap = {
        type = "int";
        default = 0;
        description = "Height of gap between groupbar indicator and title";
        limits = "[0 - 64]";
      };
      indicator_height = {
        type = "int";
        default = 3;
        description = "Height of the groupbar indicator";
        limits = "[0 - 64]";
      };
      stacked = {
        type = "bool";
        default = false;
        description = "Render the groupbar as a vertical stack";
      };
      priority = {
        type = "int";
        default = 3;
        description = "Sets the decoration priority for groupbars";
        limits = "[0 - 6]";
      };
      render_titles = {
        type = "bool";
        default = true;
        description = "Whether to render titles in the group bar decoration";
      };
      scrolling = {
        type = "bool";
        default = true;
        description = "Whether scrolling in the groupbar changes group active window";
      };
      middle_click_close = {
        type = "bool";
        default = true;
        description = "Whether middle clicking the groupbar closes the clicked window";
      };
      rounding = {
        type = "int";
        default = 1;
        description = "How much to round the indicator";
        limits = "[0 - 40]";
      };
      rounding_power = {
        type = "float";
        default = 2.0;
        description = "Adjusts the curve used for rounding groupbar corners, larger is smoother, 1.0 is a triangular corner, 2.0 is a circle, 4.0 is a squircle";
        limits = "[1.0 - 10.0]";
      };
      gradient_rounding = {
        type = "int";
        default = 2;
        description = "How much to round the gradients";
        limits = "[0 - 100]";
      };
      gradient_rounding_power = {
        type = "float";
        default = 2.0;
        description = "Adjusts the curve used for rounding gradient corners, larger is smoother, 1.0 is a triangular corner, 2.0 is a circle, 4.0 is a squircle";
        limits = "[1.0 - 10.0]";
      };
      round_only_edges = {
        type = "bool";
        default = true;
        description = "Round only the indicator edges of the entire groupbar";
      };
      gradient_round_only_edges = {
        type = "bool";
        default = true;
        description = "Round only the gradient edges of the entire groupbar";
      };
      text_color = {
        type = "str";
        default = "0xffffffff";
        description = "Color for window titles in the groupbar";
      };
      text_color_inactive = {
        type = "nullable:str";
        default = null;
        description = "Color for inactive windows' titles in the groupbar, if unset, defaults to text_color";
      };
      text_color_locked_active = {
        type = "nullable:str";
        default = null;
        description = "Color for the active window's title in a locked group, if unset, defaults to text_color";
      };
      text_color_locked_inactive = {
        type = "nullable:str";
        default = null;
        description = "Color for inactive windows' titles in locked groups, if unset, defaults to text_color_inactive";
      };
      col = {
        active = {
          type = "gradient";
          default = "0x66ffff00";
          description = "Active group bar background color";
        };
        inactive = {
          type = "gradient";
          default = "0x66777700";
          description = "Inactive (out of focus) group bar background color";
        };
        locked_active = {
          type = "gradient";
          default = "0x66ff5500";
          description = "Active locked group bar background color";
        };
        locked_inactive = {
          type = "gradient";
          default = "0x66775500";
          description = "Inactive locked group bar background color";
        };
      };
      gaps_out = {
        type = "int";
        default = 2;
        description = "Gap size between gradients and window";
        limits = "[0 - 20]";
      };
      gaps_in = {
        type = "int";
        default = 2;
        description = "Gap size between gradients";
        limits = "[0 - 20]";
      };
      keep_upper_gap = {
        type = "bool";
        default = true;
        description = "Add or remove upper gap";
      };
      text_offset = {
        type = "int";
        default = 0;
        description = "Adjust vertical position for titles";
        limits = "[-20 - 20]";
      };
      text_padding = {
        type = "int";
        default = 0;
        description = "Set horizontal padding for titles";
        limits = "[0 - 22]";
      };
      blur = {
        type = "bool";
        default = false;
        description = "Applies blur to the groupbar indicators and gradients";
      };
    };
  };
  misc = {
    disable_hyprland_logo = {
      type = "bool";
      default = true;
      description = "Disables the random Hyprland logo/anime girl background. :(";
    };
    disable_splash_rendering = {
      type = "bool";
      default = false;
      description = "Disables the Hyprland splash rendering (the small random bit of text on the background). Requires a monitor reload to take effect. Note hyprpaper has its own setting to disable it";
    };
    col = {
      splash = {
        type = "str";
        default = "0x55ffffff";
        description = "Changes the color of the splash text (requires a monitor reload to take effect)";
      };
    };
    font_family = {
      type = "str";
      default = "Sans";
      description = "Sets the global default font used to render text";
    };
    splash_font_family = {
      type = "nullable:str";
      default = null;
      description = "Changes the font used to render the splash text, selected from system fonts (requires a monitor reload to take effect)";
    };
    force_default_wallpaper = {
      type = "int";
      default = 0;
      description = "Enforce any of the 3 default wallpapers. 0 - disables the anime background, 1 - disables the anime background, 2 - enables anime background, -1 - random";
      limits = "[-1 - 2]";
    };
    vrr = {
      type = "int";
      default = 0;
      description = "Controls the VRR (Adaptive Sync) of your monitors. 0 - off, 1 - on, 2 - fullscreen only, 3 - fullscreen with `video` or `game` content type";
      limits = "[0 - 3]";
    };
    mouse_move_enables_dpms = {
      type = "bool";
      default = false;
      description = "If DPMS is set to off, wake up the monitors if the mouse moves";
    };
    key_press_enables_dpms = {
      type = "bool";
      default = false;
      description = "If DPMS is set to off, wake up the monitors if a key is pressed";
    };
    name_vk_after_proc = {
      type = "bool";
      default = true;
      description = "Name virtual keyboards after the processes that create them, e.g. `/usr/bin/fcitx5` will have hl-virtual-keyboard-fcitx5";
    };
    always_follow_on_dnd = {
      type = "bool";
      default = true;
      description = "Will make mouse focus follow the mouse when dragging and dropping. Recommended to leave it enabled, especially for people using focus follows mouse at 0";
    };
    animate_manual_resizes = {
      type = "bool";
      default = false;
      description = "If true, will animate manual window resizes/moves";
    };
    animate_mouse_windowdragging = {
      type = "bool";
      default = false;
      description = "If true, will animate windows being dragged by mouse, note that this can cause weird behavior on some curves";
    };
    disable_autoreload = {
      type = "bool";
      default = false;
      description = "If true, the config will not reload automatically on save, and instead needs to be reloaded with `hyprctl reload`. Might save on battery";
    };
    enable_swallow = {
      type = "bool";
      default = false;
      description = "Enable window swallowing";
    };
    swallow_regex = {
      type = "nullable:str";
      default = null;
      description = "The _class_ regex to be used for windows that should be swallowed (usually, a terminal)";
    };
    swallow_exception_regex = {
      type = "nullable:str";
      default = null;
      description = "The _title_ regex to be used for windows that should _not_ be swallowed by the windows specified in swallow_regex, e.g. `wev`. The regex is matched against the parent, e.g. Kitty, window's title on the assumption that it changes to whatever process it's running";
    };
    focus_on_activate = {
      type = "bool";
      default = false;
      description = "Whether Hyprland should focus an app that requests to be focused (an `activate` request)";
    };
    mouse_move_focuses_monitor = {
      type = "bool";
      default = true;
      description = "Whether mouse moving into a different monitor should focus it";
    };
    allow_session_lock_restore = {
      type = "bool";
      default = false;
      description = "If true, will allow you to restart a lock screen app in case it crashes";
    };
    session_lock_xray = {
      type = "bool";
      default = false;
      description = "If true, keep rendering workspaces below your lock screen";
    };
    session_lock_blur = {
      type = "bool";
      default = false;
      description = "Enables blur for lock screen. `session_lock_xray` must be enabled";
    };
    background_color = {
      type = "str";
      default = "0x111111";
      description = "Change the background color (requires enabled `disable_hyprland_logo`)";
    };
    close_special_on_empty = {
      type = "bool";
      default = true;
      description = "Close the special workspace if the last window is removed";
    };
    on_focus_under_fullscreen = {
      type = "int";
      default = 2;
      description = "If there is a fullscreen or maximized window, decide whether a tiled window requested to focus should replace it, stay behind or disable the fullscreen/maximized state. 0 - ignore focus request (keep focus on fullscreen window), 1 - takes over, 2 - unfullscreen/unmaximize";
      limits = "[0 - 2]";
    };
    exit_window_retains_fullscreen = {
      type = "int";
      default = 0;
      description = "Whether closing a fullscreen window makes the next focused window to be fullscreened. 0 - disabled, 1 - enabled, 2 - only when closing a grouped window, 3 - only when closing a non-grouped window";
      limits = "[0 - 3]";
    };
    initial_workspace_tracking = {
      type = "int";
      default = 1;
      description = "If enabled, windows will open on the workspace they were invoked on. 0 - disabled, 1 - single-shot, 2 - persistent (all children too)";
    };
    initial_workspace_token_timeout = {
      type = "int";
      default = 10;
      description = "the time in seconds a window has to open on its invoked workspace before the tracking token expires.";
      limits = "[1 - 3600]";
    };
    middle_click_paste = {
      type = "bool";
      default = true;
      description = "Whether to enable middle-click-paste (aka primary selection)";
    };
    render_unfocused_fps = {
      type = "int";
      default = 15;
      description = "The maximum limit for render_unfocused windows' FPS in the background (see also [Window-Rules](../rules/window-rules/#dynamic-effects), e.g. `render_unfocused`)";
      limits = "[1 - 120]";
    };
    disable_xdg_env_checks = {
      type = "bool";
      default = false;
      description = "Disable the warning if XDG environment is externally managed";
    };
    disable_hyprland_guiutils_check = {
      type = "bool";
      default = false;
      description = "Disable the warning if hyprland-guiutils is not installed";
    };
    disable_watchdog_warning = {
      type = "bool";
      default = false;
      description = "Disables the warning about not using start-hyprland";
    };
    lockdead_screen_delay = {
      type = "int";
      default = 1000;
      description = "Delay in ms after which the \"lockdead\" screen will appear in case a lock screen app fails to cover all the outputs";
      limits = "[0 - 5000]";
    };
    enable_anr_dialog = {
      type = "bool";
      default = true;
      description = "Whether to enable the ANR (app not responding) dialog when your apps hang";
    };
    anr_missed_pings = {
      type = "int";
      default = 5;
      description = "Number of missed pings before showing the ANR dialog";
      limits = "[1 - 20]";
    };
    screencopy_force_8b = {
      type = "bool";
      default = true;
      description = "Forces 8 bit screencopy";
    };
    disable_scale_notification = {
      type = "bool";
      default = false;
      description = "Disables notification popup when a monitor fails to set a suitable scale";
    };
    size_limits_tiled = {
      type = "bool";
      default = false;
      description = "Whether to apply min_size and max_size rules to tiled windows";
    };
    bell_sound = {
      type = "str";
      default = "default";
      description = "Path to custom wav/ogg system bell. \"none\" or an empty string mutes it. \"default\" uses the system's current one";
    };
    new_float_force_onscreen = {
      type = "int";
      default = 2;
      description = "same as `float_force_onscreen`, but specifically for newly-spawned floating windows";
      limits = "[0 - 2]";
    };
    float_force_onscreen = {
      type = "int";
      default = 0;
      description = "whether/how existing floating windows should be constrained to stay on-screen. 0 - no constraints, 1 - must be partially onscreen, 2 - must be fully onscreen";
      limits = "[0 - 2]";
    };
  };
  layers = {
    allow_new_top_layers_over_existing_fullscreen = {
      type = "bool";
      default = true;
      description = "If false, newly mapped layers are not allowed to render over existing covering fullscreen window. Note that fullscreen hides all pre-existing top layers regardless of this setting";
    };
    layers_hog_keyboard_focus = {
      type = "bool";
      default = true;
      description = "If true, will make keyboard-interactive layers keep their focus on mouse move, e.g. `wofi`, `bemenu`";
    };
  };
  binds = {
    pass_mouse_when_bound = {
      type = "bool";
      default = false;
      description = "If enabled, will pass the mouse events to apps/dragging windows around if a keybind has been triggered";
    };
    scroll_event_delay = {
      type = "int";
      default = 300;
      description = "In ms, how many ms to wait after a scroll event to allow passing another one for the binds";
      limits = "[0 - 2000]";
    };
    workspace_back_and_forth = {
      type = "int";
      default = 0;
      description = "An attempt to switch to the currently focused workspace will instead switch to the previous workspace, akin to i3's `_auto_back_and_forth_`. `0` - disabled, `1` - enabled, `2` - per monitor";
      limits = "[0 - 2]";
    };
    hide_special_on_workspace_change = {
      type = "bool";
      default = false;
      description = "If enabled, changing the active workspace (including to itself) will hide the special workspace on the monitor where the newly active workspace resides";
    };
    allow_workspace_cycles = {
      type = "bool";
      default = false;
      description = "If enabled, workspaces don't forget their previous workspace, so cycles can be created by switching to the first workspace in a sequence, then endlessly going to the previous workspace";
    };
    workspace_center_on = {
      type = "int";
      default = 1;
      description = "Whether switching workspaces should center the cursor on the workspace (0) or on the last active window for that workspace (1)";
      limits = "[0 - 1]";
    };
    focus_preferred_method = {
      type = "int";
      default = 0;
      description = "Sets the preferred focus finding method when using `hl.dsp.focus({ direction })`/`hl.dsp.window.move({ direction })`/etc. `0` - most recent active window has priority, `1` - longer shared edges have priority)";
      limits = "[0 - 1]";
    };
    ignore_group_lock = {
      type = "bool";
      default = false;
      description = "If enabled, dispatchers like `hl.dsp.window.move({ into_group })` and `hl.dsp.window.move({ out_of_group })` will ignore lock per group";
    };
    movefocus_cycles_fullscreen = {
      type = "bool";
      default = false;
      description = "If enabled, when focus is on a fullscreen window, it allows `hl.dsp.focus({ direction })` to seek windows. If disabled, it will seek just monitors.";
    };
    movefocus_cycles_groupfirst = {
      type = "bool";
      default = false;
      description = "If enabled, when in a grouped window, `hl.dsp.focus({ direction })` will cycle windows in the groups first, then at each ends of the tabs, it'll move on to other windows/groups";
    };
    disable_keybind_grabbing = {
      type = "bool";
      default = false;
      description = "If enabled, apps that request keybinds to be disabled, e.g. `VMs`, will not be able to do so";
    };
    window_direction_monitor_fallback = {
      type = "bool";
      default = true;
      description = "If enabled, moving a window or focus over the edge of a monitor with a direction will move it to the next monitor in that direction";
    };
    allow_pin_fullscreen = {
      type = "bool";
      default = false;
      description = "If enabled, allow fullscreen to pinned windows, and restore their pinned status afterwards";
    };
    client_requested_fs_uses_layout_handler = {
      type = "bool";
      default = true;
      description = "If false, client requested FS will use default FS handler";
    };
    drag_threshold = {
      type = "int";
      default = 0;
      description = "Movement threshold in pixels for window dragging and `click`/`drag` bind flags. `0` means disabled";
      limits = "[0 - ...]";
    };
    drag_center_window = {
      type = "bool";
      default = true;
      description = "Whether to center the window on the pointer, or use the initial hotspot";
    };
  };
  xwayland = {
    enabled = {
      type = "bool";
      default = true;
      description = "Allow running applications using X11";
    };
    use_nearest_neighbor = {
      type = "bool";
      default = true;
      description = "Uses the nearest neighbor filtering for Xwayland apps, making them pixelated rather than blurry";
    };
    force_zero_scaling = {
      type = "bool";
      default = false;
      description = "Forces a scale of 1 on Xwayland windows on scaled displays";
    };
    create_abstract_socket = {
      type = "bool";
      default = false;
      description = "Create the [abstract Unix domain socket](../../extra/xwayland/#abstract-unix-domain-socket) for Xwayland connections. Xwayland restart is required for changes to take effect; Linux only";
    };
  };
  opengl = { };
  render = {
    direct_scanout = {
      type = "int";
      default = 0;
      description = "Enables direct scanout. Direct scanout attempts to reduce lag when there is only one fullscreen application on a screen (game). It is also recommended to set this to false if the fullscreen application shows graphical glitches. `0` - disabled, `1` - enabled, `2` - auto (enabled with content type 'game')";
      limits = "[0 - 2]";
    };
    expand_undersized_textures = {
      type = "bool";
      default = true;
      description = "Whether to expand undersized textures along the edge, or rather stretch the entire texture";
    };
    xp_mode = {
      type = "bool";
      default = false;
      description = "Disables back buffer and bottom layer rendering";
    };
    ctm_animation = {
      type = "int";
      default = 2;
      description = "Whether to enable a fade animation for CTM changes (hyprsunset). 2 means \"auto\" which disables them on NVIDIA";
      limits = "[0 - 2]";
    };
    cm_enabled = {
      type = "bool";
      default = true;
      description = "Whether the color management pipeline should be enabled or not. Requires restart";
    };
    send_content_type = {
      type = "bool";
      default = true;
      description = "Report content type to allow monitor profile autoswitch (may result in a black screen during the switch)";
    };
    cm_auto_hdr = {
      type = "int";
      default = 1;
      description = "Auto-switch to HDR in fullscreen when needed. `0` - disabled, `1` - switch to `hdr`, `2` - switch to `hdredid`";
      limits = "[0 - 2]";
    };
    new_render_scheduling = {
      type = "bool";
      default = false;
      description = "Automatically uses triple buffering when needed, improves FPS on underpowered devices";
    };
    async_commit = {
      type = "bool";
      default = false;
      description = "Send DRM commits asynchronously when possible, reducing hw cursor latency";
    };
    non_shader_cm = {
      type = "int";
      default = 2;
      description = "Enable CM without shader. `0` - disable, `1` - whenever possible, `2` - DS and passthrough only, `3` - disable and ignore CM issues. Options: [0 - 3]";
      limits = "[0 - 3]";
    };
    cm_sdr_eotf = {
      type = "str";
      default = "default";
      description = "Default transfer function for displaying SDR apps. `default` - Use default value (sRGB), `gamma22` - treat unspecified as Gamma 2.2, `gamma22force` - treat unspecified and sRGB as Gamma 2.2, `srgb` - treat unspecified as sRGB. Options: `\"default\"`/`\"gamma22\"`/`\"gamma22force\"`/`\"srgb\"`";
    };
    commit_timing_enabled = {
      type = "bool";
      default = true;
      description = "Enable commit timing proto. Requires restart";
    };
    icc_vcgt_enabled = {
      type = "bool";
      default = true;
      description = "Enable sending VCGT ramps to KMS with ICC profiles";
    };
    use_shader_blur_blend = {
      type = "bool";
      default = false;
      description = "Use experimental blurred bg blending (glitched on rotated screens). Set to `true` if blur is missing with fp16 or `keep_unmodified_copy`";
    };
    use_fp16 = {
      type = "int";
      default = 2;
      description = "Use FP16 buffers internally. `0` - disabled, `1` - enabled, `2` - enabled in HDR mode";
      limits = "[0 - 2]";
    };
    keep_unmodified_copy = {
      type = "int";
      default = 2;
      description = "Keep unmodified SDR frame copy for screensharing. `0` - disabled, `1` - enabled, `2` - auto (enabled in HDR with SDR modifiers). Set to 1 if screenshots are transparent";
      limits = "[0 - 2]";
    };
    non_shader_cm_interop = {
      type = "int";
      default = 2;
      description = "`0` - external ctm (hyprsunset, etc.) is disabled in fullscreen, `1` - external ctm is enabled in fullscreen, `2` - external ctm is disabled for fullscreen photo/video/game content types";
      limits = "[0 - 2]";
    };
    fp16_sdr_tf = {
      type = "int";
      default = 0;
      description = "Internal workbuffer transfer function for fp16 in SDR mode. 0 - monitor, 1 - linear";
      limits = "[0 - 1]";
    };
    not_shown_fifo_lock = {
      type = "int";
      default = 0;
      description = "Control fifo locking for not shown surfaces. always - use fifo lock for any surface, ignore_unfocused - ignore render_unfocused windows, never - skip locking invisible surfaces";
      limits = "[0 - 2]";
    };
  };
  cursor = {
    invisible = {
      type = "bool";
      default = false;
      description = "Don't render cursors";
    };
    no_hardware_cursors = {
      type = "int";
      default = 2;
      description = "Disables hardware cursors. `0` - use hw cursors if possible, `1` - don't use hw cursors, `2` - auto (disable when tearing)";
      limits = "[0 - 2]";
    };
    no_break_fs_vrr = {
      type = "int";
      default = 2;
      description = "Disables scheduling new frames on cursor movement for fullscreen apps with VRR enabled to avoid framerate spikes (may require `no_hardware_cursors` set to `1`). `0` - disabled, `1` - enabled, `2` - auto (enabled with content type 'game')";
      limits = "[0 - 2]";
    };
    min_refresh_rate = {
      type = "int";
      default = 24;
      description = "Minimum refresh rate for cursor movement when `no_break_fs_vrr` is active. Set to minimum supported refresh rate or higher";
      limits = "[10 - 500]";
    };
    hotspot_padding = {
      type = "int";
      default = 0;
      description = "The padding, in logical px, between screen edges and the cursor";
      limits = "[0 - 20]";
    };
    inactive_timeout = {
      type = "float";
      default = 0.0;
      description = "In seconds, after how many seconds of cursor's inactivity to hide it. Set to `0` for never";
      limits = "[0 - 20]";
    };
    no_warps = {
      type = "bool";
      default = false;
      description = "If true, will not warp the cursor in many cases (focusing, keybinds, etc.)";
    };
    persistent_warps = {
      type = "bool";
      default = false;
      description = "When a window is refocused, the cursor returns to its last position relative to that window, rather than to the centre";
    };
    warp_on_change_workspace = {
      type = "int";
      default = 0;
      description = "Move the cursor to the last focused window after changing the workspace. `0` - Disabled, `1` - Enabled, `2` - Force (ignores cursor:no_warps option)";
      limits = "[0 - 2]";
    };
    warp_on_monitor_change = {
      type = "int";
      default = -1;
      description = "Move the cursor to the last focused window when focusing a different monitor. `-1` - follow value of `cursor:warp_on_change_workspace`, `0` - disabled, `1` - enabled, `2` - force even if `cursor:no_warps`";
      limits = "[-1 - 2]";
    };
    warp_on_toggle_special = {
      type = "int";
      default = 0;
      description = "Move the cursor to the last focused window when toggling a special workspace. `0` - Disabled, `1` - Enabled, `2` - Force (ignores cursor:no_warps option)";
      limits = "[0 - 2]";
    };
    default_monitor = {
      type = "nullable:str";
      default = null;
      description = "The name of a default monitor for the cursor to be set to on startup (see `hyprctl monitors` for names)";
    };
    zoom_factor = {
      type = "float";
      default = 1.0;
      description = "The factor to zoom by around the cursor. Like a magnifying glass. Minimum 1.0 (meaning no zoom)";
      limits = "[1 - 10]";
    };
    zoom_rigid = {
      type = "bool";
      default = false;
      description = "Whether the zoom should follow the cursor rigidly (cursor is always centered if it can be) or loosely";
    };
    zoom_disable_aa = {
      type = "bool";
      default = false;
      description = "Disable antialiasing when zooming, which means things will be pixelated instead of blurry";
    };
    zoom_detached_camera = {
      type = "bool";
      default = true;
      description = "Detach the camera from the mouse when zoomed in, only ever moving the camera to keep the mouse in view when it goes past the screen edges";
    };
    enable_hyprcursor = {
      type = "bool";
      default = true;
      description = "Whether to enable hyprcursor support";
    };
    hide_on_key_press = {
      type = "bool";
      default = false;
      description = "Hides the cursor when you press any key until the mouse is moved";
    };
    hide_on_touch = {
      type = "bool";
      default = true;
      description = "Hides the cursor when the last input was a touch input until a mouse input is done";
    };
    hide_on_tablet = {
      type = "bool";
      default = false;
      description = "Hides the cursor when the last input was a tablet input until a mouse input is done";
    };
    use_cpu_buffer = {
      type = "int";
      default = 2;
      description = "Makes HW cursors use a CPU buffer. Required on NVIDIA to have HW cursors. `0` - disabled, `1` - enabled, `2` - auto (enabled with NVIDIA)";
      limits = "[0 - 2]";
    };
    sync_gsettings_theme = {
      type = "bool";
      default = true;
      description = "Sync XCursor theme with GSettings. It applies cursor-theme and cursor-size on theme load to GSettings making most CSD GTK based clients use the same XCursor theme and size";
    };
    warp_back_after_non_mouse_input = {
      type = "bool";
      default = false;
      description = "Warp the cursor back to where it was after using a non-mouse input to move it, and then returning back to the mouse";
    };
  };
  ecosystem = {
    no_update_news = {
      type = "bool";
      default = false;
      description = "Disable the popup that shows up when you update Hyprland to a new version";
    };
    no_donation_nag = {
      type = "bool";
      default = false;
      description = "Disable the popup that shows up twice a year encouraging to donate";
    };
    enforce_permissions = {
      type = "bool";
      default = false;
      description = "Whether to enable [permission control](../advanced-configuration/permissions)";
    };
  };
  debug = {
    overlay = {
      type = "bool";
      default = false;
      description = "Print the debug performance overlay. Disable VFR for accurate results";
    };
    damage_blink = {
      type = "bool";
      default = false;
      description = "(epilepsy warning!) Flash areas updated with damage tracking";
    };
    gl_debugging = {
      type = "bool";
      default = false;
      description = "Enables OpenGL debugging with glGetError and EGL_KHR_debug, requires a restart after changing";
    };
    disable_logs = {
      type = "bool";
      default = false;
      description = "Disable logging to a file";
    };
    disable_time = {
      type = "bool";
      default = true;
      description = "Disables time logging";
    };
    damage_tracking = {
      type = "int";
      default = 2;
      description = "Redraw only the needed bits of the display. Do **not** change. None - 0, monitor - 1, full - 2";
      limits = "[0 - 2]";
    };
    enable_stdout_logs = {
      type = "bool";
      default = false;
      description = "Enables logging to stdout";
    };
    manual_crash = {
      type = "int";
      default = 0;
      description = "Set to 1 and then back to 0 to crash Hyprland";
      limits = "[0 - 1]";
    };
    suppress_errors = {
      type = "bool";
      default = false;
      description = "If enabled, Hyprland will not display config file parsing errors";
    };
    disable_scale_checks = {
      type = "bool";
      default = false;
      description = "Disables verification of the scale factors. Will result in pixel alignment and rounding errors";
    };
    error_limit = {
      type = "int";
      default = 5;
      description = "Limits the number of displayed config file parsing errors";
      limits = "[0 - 20]";
    };
    error_position = {
      type = "int";
      default = 0;
      description = "Sets the position of the error bar. `0` - top, `1` bottom";
      limits = "[0 - 1]";
    };
    colored_stdout_logs = {
      type = "bool";
      default = true;
      description = "Enables colors in the stdout logs";
    };
    log_damage = {
      type = "bool";
      default = false;
      description = "Enables logging the damage";
    };
    pass = {
      type = "bool";
      default = false;
      description = "Enables render pass debugging";
    };
    full_cm_proto = {
      type = "bool";
      default = false;
      description = "Claims support for all cm proto features (requires restart)";
    };
    ds_handle_same_buffer = {
      type = "bool";
      default = true;
      description = "special case for direct scanout with unmodified buffer";
    };
    ds_handle_same_buffer_fifo = {
      type = "bool";
      default = true;
      description = "special case for direct scanout with unmodified buffer unlocks fifo";
    };
    render_solitary_wo_damage = {
      type = "bool";
      default = false;
      description = "render solitary window with empty damage";
    };
    vfr = {
      type = "bool";
      default = true;
      description = "Controls the VFR status of Hyprland. Heavily recommended to leave enabled to conserve resources";
    };
    invalidate_buffers = {
      type = "int";
      default = 1;
      description = "Allow buffer invalidation (invalidation increases performance but produces glitches on some systems). 0 - not allowed, 1 - allowed";
      limits = "[0 - 1]";
    };
    invalidate_fp16 = {
      type = "nullable:int";
      default = null;
      description = "";
    };
  };
  layout = {
    single_window_aspect_ratio = {
      type = "vec2";
      default = { x = 0; y = 0; };
      description = "Whenever only a single window is shown on a screen, add padding so that it conforms to the specified aspect ratio. A value like `4 3` on a 16:9 screen will make it a 4:3 window in the middle with padding to the sides";
    };
    single_window_aspect_ratio_tolerance = {
      type = "float";
      default = 0.1;
      description = "Sets a tolerance for `single_window_aspect_ratio`, so that if the padding that would have been added is smaller than the specified fraction of the height or width of the screen, it will not attempt to adjust the window size";
      limits = "[0.0 - 1.0]";
    };
  };
  dwindle = {
    force_split = {
      type = "int";
      default = 0;
      description = "0 - split follows mouse, 1 - always split to the left (new = left or top), 2 - always split to the right (new = right or bottom)";
      limits = "[0 - 2]";
    };
    preserve_split = {
      type = "bool";
      default = true;
      description = "If enabled, the split (side/top) will not change regardless of what happens to the container";
    };
    smart_split = {
      type = "bool";
      default = false;
      description = "If enabled, allows a more precise control over the window split direction based on the cursor's position. The window is conceptually divided into four triangles, and cursor's triangle determines the split direction. This feature also turns on `preserve_split`";
    };
    smart_resizing = {
      type = "bool";
      default = true;
      description = "If enabled, resizing direction will be determined by the mouse's position on the window (nearest to which corner). Otherwise, it is based on the window's tiling position";
    };
    permanent_direction_override = {
      type = "bool";
      default = false;
      description = "If enabled, makes the preselect direction persist until either this mode is turned off, another direction is specified, or a non-direction is specified (anything other than `l`, `r`, `u`/`t`, `d`/`b`)";
    };
    special_scale_factor = {
      type = "nullable:float";
      default = null;
      description = "";
    };
    split_width_multiplier = {
      type = "float";
      default = 1.0;
      description = "Specifies the auto-split width multiplier. Multiplying window size is useful on widescreen monitors where window W > H even after several splits";
      limits = "[0.1 - 3.0]";
    };
    use_active_for_splits = {
      type = "bool";
      default = true;
      description = "Whether to prefer the active window or the mouse position for splits";
    };
    default_split_ratio = {
      type = "float";
      default = 1.0;
      description = "The default split ratio on window open. 1 means an even 50/50 split";
      limits = "[0.1 - 1.9]";
    };
    split_bias = {
      type = "int";
      default = 0;
      description = "Specifies which window will receive the split ratio. 0 - directional (the top or left window), 1 - the current window";
      limits = "[0 - 1]";
    };
    precise_mouse_move = {
      type = "bool";
      default = false;
      description = "Dragging and dropping windows will place them more precisely, based on where your mouse is";
    };
  };
  master = {
    allow_small_split = {
      type = "bool";
      default = false;
      description = "Enable adding additional master windows in a horizontal split style";
    };
    special_scale_factor = {
      type = "nullable:float";
      default = null;
      description = "";
    };
    mfact = {
      type = "float";
      default = 0.55;
      description = "The size as a percentage of the master window, for example `mfact = 0.70` would mean 70% of the screen will be the master window, and 30% the slave";
      limits = "[0 - 1]";
    };
    new_status = {
      type = "str";
      default = "master";
      description = "`\"master\"` - new window becomes master, `\"slave\"` - new windows are added to slave stack, `\"inherit\"` - inherit from focused window";
    };
    new_on_top = {
      type = "bool";
      default = false;
      description = "Whether a newly open window should be on the top of the stack";
    };
    new_on_active = {
      type = "str";
      default = "none";
      description = "`\"before\"`, `\"after\"` - place new window relative to the focused window, `\"none\"` - place new window according to the value of `new_on_top`";
    };
    orientation = {
      type = "str";
      default = "left";
      description = "Default placement of the master area";
      limits = "`\"left\"`, `\"right\"`, `\"top\"`, `\"bottom\"`, `\"center\"`";
    };
    slave_count_for_center_master = {
      type = "int";
      default = 2;
      description = "When using orientation=center, make the master window centered only when at least this many slave windows are open. (Set 0 to always center master)";
      limits = "[0 - 10]";
    };
    center_master_fallback = {
      type = "str";
      default = "left";
      description = "Set fallback for center master when slaves are less than `slave_count_for_center_master`";
      limits = "`\"left\"`, `\"right\"`, `\"top\"`, `\"bottom\"`";
    };
    center_ignores_reserved = {
      type = "nullable:bool";
      default = null;
      description = "";
    };
    smart_resizing = {
      type = "bool";
      default = true;
      description = "If enabled, resizing direction will be determined by the mouse's position on the window (nearest to which corner). Otherwise, it is based on the window's tiling position";
    };
    drop_at_cursor = {
      type = "bool";
      default = true;
      description = "When enabled, dragging and dropping windows will put them at the cursor position. Otherwise, when dropped at the stack side, they will go to the top/bottom of the stack depending on new_on_top";
    };
    always_keep_position = {
      type = "bool";
      default = false;
      description = "Whether to keep the master window in its configured position when there are no slave windows";
    };
    focus_master_on_close = {
      type = "bool";
      default = false;
      description = "When enabled, closing a window focuses the master window";
    };
  };
  scrolling = {
    fullscreen_on_one_column = {
      type = "bool";
      default = true;
      description = "When enabled, a single column on a workspace will always span the entire screen";
    };
    column_width = {
      type = "float";
      default = 0.5;
      description = "The default width of a column";
      limits = "[0.1 - 1.0]";
    };
    focus_fit_method = {
      type = "int";
      default = 1;
      description = "When a column is focused, what method should be used to bring it into view. 0 - center, 1 - fit, 2 - clamped_center";
      limits = "[0 - 2]";
    };
    follow_focus = {
      type = "int";
      default = 1;
      description = "Behaviour of the scrolling tape when a window is in focus. 0: Focus doesn't cause tape move. 1: Focus may cause tape move, mouse click always moves the tape. 2: Focus may cause tape move.";
      limits = "[0 - 2]";
    };
    follow_min_visible = {
      type = "float";
      default = 0.4;
      description = "When a window is focused, require that at least a given fraction of it is visible for focus to follow. Hard input (e.g., binds, clicks) will always follow";
      limits = "[0.0 - 1.0]";
    };
    explicit_column_widths = {
      type = "str";
      default = "0.333, 0.5, 0.667, 1.0";
      description = "A comma-separated list of preconfigured widths for `colresize +conf/-conf`";
    };
    direction = {
      type = "str";
      default = "right";
      description = "Direction in which new windows appear and the layout scrolls. `\"left\"`/`\"right\"`/`\"down\"`/`\"up\"`";
    };
    wrap_focus = {
      type = "bool";
      default = true;
      description = "When enabled, causes `hl.dsp.layout(\"focus l/r\")` to wrap around at the beginning and end";
    };
    wrap_swapcol = {
      type = "bool";
      default = true;
      description = "When enabled, causes `hl.dsp.layout(\"swapcol l/r\")` to wrap around at the beginning and end";
    };
  };
  experimental = {
    wp_cm_1_2 = {
      type = "bool";
      default = false;
      description = "Allow wp-cm-v1 version 2";
    };
  };
  input_capture = {
    capture_modifiers = {
      type = "bool";
      default = false;
      description = "If enabled, modifiers are also captured and sent to the program";
    };
    enforce_barriers = {
      type = "bool";
      default = true;
      description = "If enabled, throw a Wayland error when an invalid barrier is received";
    };
  };
  quirks = {
    prefer_hdr = {
      type = "int";
      default = 0;
      description = "Report HDR mode as preferred. `0` - disabled, `1` - always, `2` - gamescope only";
      limits = "[0 - 1]";
    };
    skip_non_kms_dmabuf_formats = {
      type = "bool";
      default = false;
      description = "do not report dmabuf formats which cannot be imported into KMS";
    };
  };
}
