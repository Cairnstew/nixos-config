{ lib, ... }:
let
  inherit (lib) mkOption types;
  spec = import ./spec.nix;

  # ── Lua value types ────────────────────────────────────────────────────
  # Shared by the typed keyword options (window rules, devices, …).
  primitive = types.oneOf [ types.bool types.int types.float types.str ];

  vec2 = types.submodule {
    options = {
      x = mkOption { type = (types.either types.int types.float); default = 0; description = "Horizontal component (int or float)."; };
      y = mkOption { type = (types.either types.int types.float); default = 0; description = "Vertical component (int or float)."; };
    };
  };

  gradient = types.submodule {
    options = {
      colors = mkOption {
        type = types.listOf types.str;
        default = [ ];
        example = [ "rgba(89b4faff)" "rgba(cba6f7ff)" ];
        description = "Colour stops. A single stop is a flat colour; two or more create a gradient.";
      };
      angle = mkOption {
        type = types.int;
        default = 0;
        description = "Gradient angle in degrees.";
      };
      whole_monitor = mkOption {
        type = types.nullOr types.bool;
        default = null;
        description = "Draw the gradient across the whole monitor instead of the window (group borders only).";
      };
    };
  };

  rounding = types.either types.int (types.submodule {
    options = {
      top_left = mkOption { type = types.int; default = 0; description = "Top-left corner radius."; };
      top_right = mkOption { type = types.int; default = 0; description = "Top-right corner radius."; };
      bottom_left = mkOption { type = types.int; default = 0; description = "Bottom-left corner radius."; };
      bottom_right = mkOption { type = types.int; default = 0; description = "Bottom-right corner radius."; };
    };
  });

  nixType = t:
    let
      nullable = lib.hasPrefix "nullable:" t;
      base = lib.removePrefix "nullable:" t;
      ty = {
        bool = types.bool;
        int = types.int;
        float = types.float;
        str = types.str;
        gap = types.either types.int types.str;
        intOrStr = types.either types.int types.str;
        gradient = types.either types.str gradient;
        vec2 = vec2;
        rounding = rounding;
      }.${base};
    in
    if nullable then types.nullOr ty else ty;

  # ── hl.config() surface ────────────────────────────────────────────────
  # `spec.nix` is a nested attrset; leaves carry `type`/`default`.
  flatten = prefix: attrs:
    lib.concatLists (lib.mapAttrsToList
      (name: value:
        if value ? type then
          [ (value // { path = prefix ++ [ name ]; }) ]
        else
          flatten (prefix ++ [ name ]) value)
      attrs);

  mkLeaf = leaf:
    lib.setAttrByPath ([ "my" "desktop" "hyprland" "settings" ] ++ leaf.path) (mkOption {
      type = nixType leaf.type;
      default = leaf.default;
      description = leaf.description
        + lib.optionalString (leaf ? limits) " Limits: ${leaf.limits}.";
    });

  settingsOptions = lib.foldl' lib.recursiveUpdate { } (map mkLeaf (flatten [ ] spec));

  # ── Keyword surfaces ───────────────────────────────────────────────────
  # Everything Hyprland configures outside `hl.config()`: binds, rules,
  # animations, devices, gestures, permissions and plugins.
  bind = types.submodule {
    options = {
      keys = mkOption {
        type = types.str;
        example = "SUPER + G";
        description = "Key combination, e.g. `SUPER + SHIFT + S`.";
      };
      dispatcher = mkOption {
        type = types.str;
        example = ''hl.dsp.exec_cmd("firefox")'';
        description = "Lua dispatcher expression (an `hl.dsp.*` call or a Lua function reference).";
      };
      opts = mkOption {
        type = types.attrsOf primitive;
        default = { };
        example = { locked = true; repeating = true; };
        description = "Extra `hl.bind` options (`locked`, `repeating`, `release`, `mouse`, …).";
      };
    };
  };

  rule = types.submodule {
    options = {
      match = mkOption {
        type = types.attrsOf primitive;
        default = { };
        example = { class = "^(firefox)$"; };
        description = "Match criteria. Values are Hyprland regex/selector strings unless a boolean/number is used.";
      };
      rules = mkOption {
        type = types.attrsOf primitive;
        default = { };
        example = { float = true; size = "1200 800"; };
        description = "Rule actions and parameters. Merged into the rule table next to `match`.";
      };
      enabled = mkOption {
        type = types.bool;
        default = true;
        description = "Whether the rule is active.";
      };
      name = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Optional rule name for `set_enabled`/`is_enabled` runtime control.";
      };
    };
  };

  curve = types.submodule {
    options = {
      name = mkOption { type = types.str; example = "overshoot"; description = "Curve name, referenced by animation entries."; };
      type = mkOption {
        type = types.enum [ "bezier" "spring" ];
        default = "bezier";
        description = "Curve kind.";
      };
      points = mkOption {
        type = types.listOf vec2;
        default = [ ];
        example = [{ x = 0.5; y = 0.9; } { x = 0.1; y = 1.1; }];
        description = "Bezier control points (`type = \"bezier\"`).";
      };
      mass = mkOption { type = types.float; default = 1.0; description = "Spring mass (`type = \"spring\"`)."; };
      stiffness = mkOption { type = types.float; default = 70.0; description = "Spring stiffness (`type = \"spring\"`)."; };
      damping = mkOption { type = types.float; default = 10.0; description = "Spring damping (`type = \"spring\"`)."; };
    };
  };

  animation = types.submodule {
    options = {
      leaf = mkOption {
        type = types.str;
        example = "windowsIn";
        description = "Animation tree leaf (`windows`, `fadeIn`, `workspacesOut`, …).";
      };
      enabled = mkOption { type = types.bool; default = true; description = "Enable this animation."; };
      speed = mkOption {
        type = types.float;
        default = 8.0;
        description = "Duration in deciseconds (100 ms units).";
      };
      bezier = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Named bezier curve (`settings.animations.curves`).";
      };
      spring = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Named spring curve (`settings.animations.curves`). Exactly one of `bezier`/`spring` is required.";
      };
      style = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "slide";
        description = "Animation style (`slide`, `popin`, `fade`, …) with optional percentage/side suffix.";
      };
    };
  };

  gesture = types.submodule {
    options = {
      fingers = mkOption { type = types.int; default = 3; description = "Number of fingers."; };
      direction = mkOption {
        type = types.enum [
          "swipe"
          "horizontal"
          "vertical"
          "left"
          "right"
          "up"
          "down"
          "pinch"
          "pinchin"
          "pinchout"
        ];
        default = "horizontal";
        description = "Gesture direction/type (see the Hyprland gestures wiki page).";
      };
      action = mkOption {
        type = types.str;
        default = "workspace";
        example = "special";
        description = "Built-in action name (`workspace`, `special`, `close`, `float`, `fullscreen`, `move`, `resize`, `cursor_zoom`, `scroll_move`, `unset`).";
      };
      luaAction = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = ''function() hl.exec_cmd("kitty") end'';
        description = "Raw Lua function used instead of `action` (named function or lambda).";
      };
      mods = mkOption { type = types.nullOr types.str; default = null; example = "SUPER"; description = "Required modifier(s)."; };
      scale = mkOption { type = types.nullOr types.float; default = null; description = "Sensitivity scale."; };
      mode = mkOption {
        type = types.nullOr (types.enum [ "on" "once" "off" ]);
        default = null;
        description = "Gesture mode override.";
      };
      zoom_level = mkOption { type = types.nullOr types.float; default = null; description = "Zoom level for zoom gestures."; };
      workspace_name = mkOption { type = types.nullOr types.str; default = null; description = "Workspace targeted by the gesture."; };
      disable_inhibit = mkOption { type = types.bool; default = false; description = "Ignore input inhibitors."; };
    };
  };

  permission = types.submodule {
    options = {
      binary = mkOption { type = types.str; example = "/usr/bin/grim"; description = "Binary the permission applies to."; };
      type = mkOption {
        type = types.enum [
          "screencopy"
          "plugin"
          "keyboard"
          "cursorpos"
          "input-capture"
        ];
        description = "Permission type (see the Hyprland permissions page).";
      };
      mode = mkOption {
        type = types.enum [ "allow" "deny" "ask" ];
        description = "Permission mode.";
      };
    };
  };

  submap = types.submodule {
    options = {
      name = mkOption { type = types.str; example = "resize"; description = "Submap name."; };
      reset = mkOption {
        type = types.str;
        default = "reset";
        description = "Key combination that resets/leaves the submap.";
      };
      binds = mkOption { type = types.listOf bind; default = [ ]; description = "Binds active inside the submap."; };
    };
  };

  keywordOptions = {
    env = mkOption {
      type = types.attrsOf types.str;
      default = {
        XDG_CURRENT_DESKTOP = "Hyprland";
        XDG_SESSION_TYPE = "wayland";
        XDG_SESSION_DESKTOP = "Hyprland";
        GTK_THEME = "Adwaita:dark";
        XCURSOR_THEME = "Adwaita";
        XCURSOR_SIZE = "24";
      };
      example = { QT_QPA_PLATFORM = "wayland"; };
      description = "Environment variables exported to the Hyprland session (`hl.env`).";
    };

    execOnce = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [ "playerctld daemon" ];
      description = "Commands run once when the compositor starts (`hl.exec_cmd` inside `hyprland.start`).";
    };

    execShutdown = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [ "systemctl --user stop waybar" ];
      description = "Commands run on the `hyprland.shutdown` event (session exit).";
    };

    monitors = mkOption {
      type = types.listOf (types.submodule {
        options = {
          output = mkOption { type = types.str; example = "DP-1"; description = "Connector name (`hyprctl monitors`)."; };
          mode = mkOption { type = types.nullOr types.str; default = null; example = "2560x1440@144"; description = "Mode as WxH@Hz; omit for preferred."; };
          position = mkOption { type = types.nullOr types.str; default = null; example = "0x0"; description = "Layout position `XxY` or `auto`."; };
          scale = mkOption { type = types.nullOr (types.either types.int types.float); default = null; example = 1.5; description = "Scale factor or `auto`."; };
          transform = mkOption { type = types.nullOr types.int; default = null; description = "Rotation: 0=normal, 1=90°, 2=180°, 3=270°, 4-7 flipped."; };
          disabled = mkOption { type = types.nullOr types.bool; default = null; description = "Disable this output."; };
          mirror = mkOption { type = types.nullOr types.str; default = null; example = "DP-2"; description = "Mirror another output."; };
          bitdepth = mkOption { type = types.nullOr types.int; default = null; description = "Requested bit depth (10 for HDR)."; };
          vrr = mkOption { type = types.nullOr types.int; default = null; description = "VRR: 0=off, 1=on, 2=fullscreen, 3=fullscreen game/video."; };
          icc = mkOption { type = types.nullOr types.str; default = null; description = "Path to an ICC profile."; };
          cm = mkOption { type = types.nullOr types.str; default = null; example = "hdr"; description = "Colour management preset (`srgb`, `hdr`, `hdredid`, `wide`, `edid`, `auto`, …)."; };
          sdrbrightness = mkOption { type = types.nullOr types.float; default = null; description = "SDR brightness in HDR mode."; };
          sdrsaturation = mkOption { type = types.nullOr types.float; default = null; description = "SDR saturation in HDR mode."; };
          sdr_min_luminance = mkOption { type = types.nullOr types.float; default = null; description = "SDR minimum luminance."; };
          sdr_max_luminance = mkOption { type = types.nullOr types.int; default = null; description = "SDR maximum luminance."; };
          min_luminance = mkOption { type = types.nullOr types.float; default = null; description = "Panel minimum luminance."; };
          max_luminance = mkOption { type = types.nullOr types.int; default = null; description = "Panel maximum luminance."; };
          max_avg_luminance = mkOption { type = types.nullOr types.int; default = null; description = "Panel maximum average luminance."; };
          supports_hdr = mkOption { type = types.nullOr types.int; default = null; description = "Override HDR capability: 0=no, 1=yes, 2=auto."; };
          supports_wide_color = mkOption { type = types.nullOr types.int; default = null; description = "Override wide-colour capability: 0=no, 1=yes, 2=auto."; };
          sdr_eotf = mkOption { type = types.nullOr types.str; default = null; description = "SDR transfer function preset."; };
          reserved = mkOption { type = types.nullOr (types.either types.int types.str); default = null; description = "Reserved area (CSS gap syntax) for bars/panels."; };
          reserved_area = mkOption { type = types.nullOr (types.either types.int types.str); default = null; description = "Additional reserved area."; };
        };
      });
      default = [ ];
      description = ''
        Extra `hl.monitor` rules, emitted after `my.monitors`. A rule whose
        `output` matches one generated from `my.monitors` overrides only the
        fields set here (Hyprland merges monitor rules per output).
      '';
    };

    exec = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [ "systemctl --user start hyprpaper" ];
      description = "Commands run on every config load/reload (`hl.exec_cmd` at top level).";
    };

    binds = mkOption {
      type = types.listOf bind;
      default = [ ];
      description = "Extra keybinds, emitted after the built-in binds so a host can shadow them.";
    };

    windowRules = mkOption {
      type = types.listOf rule;
      default = [ ];
      description = "Typed `hl.window_rule` entries (match + actions).";
    };

    layerRules = mkOption {
      type = types.listOf rule;
      default = [ ];
      description = "Typed `hl.layer_rule` entries (match + actions).";
    };

    workspaceRules = mkOption {
      type = types.listOf (types.submodule {
        options = {
          workspace = mkOption { type = types.str; example = "3"; description = "Workspace selector."; };
          rules = mkOption {
            type = types.attrsOf primitive;
            default = { };
            example = { gapsin = 0; gapsout = 0; noshadow = true; };
            description = "Workspace rule actions (gapsin, gapsout, bordersize, layout, monitor, …).";
          };
          enabled = mkOption { type = types.bool; default = true; description = "Whether the rule is active."; };
        };
      });
      default = [ ];
      description = "Typed `hl.workspace_rule` entries.";
    };

    animations = {
      curves = mkOption {
        type = types.listOf curve;
        default = [ ];
        description = "Named bezier/spring curves (`hl.curve`).";
      };
      entries = mkOption {
        type = types.listOf animation;
        default = [ ];
        description = "Per-leaf animation settings (`hl.animation`).";
      };
    };

    devices = mkOption {
      type = types.listOf (types.submodule {
        options = {
          name = mkOption { type = types.str; description = "Device name from `hyprctl devices`."; };
          rules = mkOption {
            type = types.attrsOf primitive;
            default = { };
            example = { sensitivity = -0.5; natural_scroll = true; };
            description = "Device options (any `input.*` option that is device-local, plus `enabled`, `keybinds`, `tags`).";
          };
        };
      });
      default = [ ];
      description = "Per-device overrides (`hl.device`).";
    };

    gestures = mkOption {
      type = types.listOf gesture;
      default = [ ];
      description = "Touchpad/gesture actions (`hl.gesture`).";
    };

    permissions = mkOption {
      type = types.listOf permission;
      default = [ ];
      description = "Application permissions (`hl.permission`). Requires `ecosystem.enforce_permissions = true`.";
    };

    plugins = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [ "/etc/hypr/plugins/my-plugin.so" ];
      description = "Hyprland plugin .so paths loaded at startup (`hl.plugin.load`).";
    };

    submaps = mkOption {
      type = types.listOf submap;
      default = [ ];
      description = "Keybind submaps (`hl.define_submap`).";
    };

    extraLua = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Raw Lua statements appended after every generated setting. Escape hatch for features not modelled above.";
    };
  };
in
{
  options = lib.foldl' lib.recursiveUpdate settingsOptions [
    { my.desktop.hyprland.settings = keywordOptions; }
  ];
}
