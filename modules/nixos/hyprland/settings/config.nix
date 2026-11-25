{ config, lib, ... }:
let
  inherit (lib)
    concatMapStringsSep concatStringsSep filterAttrs mapAttrsToList optionalString
    mkIf mkAfter mapAttrs attrNames sort;

  cfg = config.my.desktop.hyprland;
  s = cfg.settings;
  spec = import ./spec.nix;

  # ── Lua serialisation ──────────────────────────────────────────────────
  luaStr = value:
    "\"" + builtins.replaceStrings [ "\\" "\"" "\n" ] [ "\\\\" "\\\"" " " ] value + "\"";

  luaVal = value:
    if builtins.isBool value then
      (if value then "true" else "false")
    else if builtins.isString value then
      luaStr value
    else if builtins.isInt value then
      toString value
    else if builtins.isFloat value then
      toString value
    else if builtins.isList value then
      "{ " + concatMapStringsSep ", " luaVal value + " }"
    else if builtins.isAttrs value then
      let
        attrs = filterAttrs (name: v: v != null) value;
      in
      if attrNames attrs == [ "x" "y" ] then
        "{ ${luaVal attrs.x}, ${luaVal attrs.y} }"
      else
        "{ " + concatStringsSep ", " (mapAttrsToList (name: v: "${name} = ${luaVal v}") attrs) + " }"
    else
      throw "luaVal: unsupported value ${builtins.toJSON value}";

  luaTable = attrs: luaVal (filterAttrs (_: v: v != null) attrs);

  # ── hl.config(): only the spec-declared leaves ─────────────────────────
  pickSpec = specNode: values:
    let
      leaves = filterAttrs
        (name: value:
          let specValue = specNode.${name} or null; in
          specValue != null
          && (if specValue ? type
          then value != null
          else values ? ${name} && value != null && value != { }))
        (if builtins.isAttrs values then values else { });
    in
    mapAttrs
      (name: value:
        if specNode.${name} ? type then value else pickSpec specNode.${name} value)
      leaves;

  configTree = pickSpec spec (
    removeAttrs s [
      "env"
      "execOnce"
      "exec"
      "binds"
      "windowRules"
      "layerRules"
      "workspaceRules"
      "animations"
      "devices"
      "gestures"
      "permissions"
      "plugins"
      "submaps"
      "extraLua"
    ]
  );

  envLines = mapAttrsToList
    (name: value: ''hl.env(${luaStr name}, ${luaStr value})'')
    s.env;

  execLines = map (cmd: ''hl.exec_cmd(${luaStr cmd})'') s.exec;

  bindLine = prefix: b:
    ''${prefix}hl.bind(${luaStr b.keys}, ${b.dispatcher}${optionalString (b.opts != { }) ", ${luaTable b.opts}"})'';

  ruleLine = fn: r:
    let
      table = { match = r.match; } // r.rules // { inherit (r) enabled; }
        // (if r.name == null then { } else { inherit (r) name; });
    in
    ''${fn}(${luaTable table})'';

  workspaceRuleLine = r:
    ''hl.workspace_rule(${luaTable ({ workspace = r.workspace; } // r.rules // { inherit (r) enabled; })})'';

  curveLine = c:
    let
      table =
        if c.type == "bezier"
        then { type = "bezier"; points = map (p: [ p.x p.y ]) c.points; }
        else { type = "spring"; inherit (c) mass stiffness damping; };
    in
    ''hl.curve(${luaStr c.name}, ${luaTable table})'';

  animationLine = a:
    ''hl.animation(${luaTable {
      inherit (a) leaf enabled speed bezier spring style;
    }})'';

  deviceLine = d: ''hl.device(${luaTable ({ name = d.name; } // d.rules)})'';

  gestureLine = g:
    let
      fields = {
        inherit (g) fingers direction mods scale mode zoom_level workspace_name disable_inhibit;
      };
    in
    if g.luaAction != null
    then
      "hl.gesture(" + "{ "
      + concatStringsSep ", "
        (mapAttrsToList (name: v: "${name} = ${luaVal v}") (filterAttrs (_: v: v != null) fields))
      + ", action = ${g.luaAction} })"
    else
      ''hl.gesture(${luaTable (filterAttrs (_: v: v != null) (fields // { inherit (g) action; }))})'';

  permissionLine = p: ''hl.permission(${luaTable { inherit (p) binary type mode; }})'';

  pluginLine = path: ''hl.plugin.load(${luaStr path})'';

  submapLines = sm: [
    ''hl.define_submap(${luaStr sm.name}, ${luaStr sm.reset}, function()''
  ] ++ map (bindLine "  ") sm.binds ++ [ "end)" ];

  binds = map (bindLine "") s.binds;
  windowRules = map (ruleLine "hl.window_rule") s.windowRules;
  layerRules = map (ruleLine "hl.layer_rule") s.layerRules;
  workspaceRules = map workspaceRuleLine s.workspaceRules;
  curves = map curveLine s.animations.curves;
  animations = map animationLine s.animations.entries;
  devices = map deviceLine s.devices;
  gestures = map gestureLine s.gestures;
  permissions = map permissionLine s.permissions;
  plugins = map pluginLine s.plugins;

  linesFor = lines: optionalString (lines != [ ]) ("\n" + concatStringsSep "\n" lines);
in
{
  config = mkIf (cfg.enable && cfg.core.enable) {
    environment.etc."xdg/hypr/hyprland.lua".text = mkAfter (''

      -- ── Settings (my.desktop.hyprland.settings) ──────────────────────────
      -- Generated from modules/nixos/hyprland/settings/spec.nix: every option
      -- is declared with its default and can be overridden per host.
      hl.config(${luaVal configTree})
    ''
    + linesFor envLines
    + linesFor execLines
    + linesFor curves
    + linesFor animations
    + linesFor binds
    + linesFor windowRules
    + linesFor layerRules
    + linesFor workspaceRules
    + linesFor devices
    + linesFor gestures
    + linesFor permissions
    + linesFor plugins
    + linesFor (builtins.concatLists (map submapLines s.submaps))
    + linesFor s.extraLua
    + optionalString (s.execOnce != [ ]) ''

      hl.on("hyprland.start", function()
      ${concatMapStringsSep "\n" (cmd: "  hl.exec_cmd(${luaStr cmd})") s.execOnce}
      end)
    '');
  };
}
