{ config, lib, pkgs, ... }:
let
  cfg = config.my.desktop.hyprland;
  wpCfg = cfg.wallpapers;

  # ── Span: auto-scale + crop one source across the monitor canvas ───────
  # The layout comes from `my.monitors` (declarative), so the crops are built
  # deterministically at build time — no `hyprctl monitors` at runtime.
  #
  # Geometry rules (Hyprland):
  #   - x/y are logical (scaled) layout coordinates and may be negative.
  #   - width/height are the mode's pixel size; an odd `transform` (1/3/5/7)
  #     rotates the output, so the logical box swaps w/h and the produced file
  #     is sized to the post-transform pixel size (h × w for 90°/270°).
  #   - the compositor applies the rotation itself: crop in layout space, never
  #     pre-rotate the crop.
  spanEnabled = wpCfg.span.enable;
  monitors = lib.filter (m: m.enabled && m.name != "") (config.my.monitors or [ ]);

  round = x: builtins.floor (x + 0.5);

  mkMonitorInfo = m:
    let
      transform = m.transform or 0;
      scale = m.scale or 1;
      rotated = lib.mod transform 2 == 1;
      logicalW = (if rotated then m.height else m.width) * 1.0 / scale;
      logicalH = (if rotated then m.width else m.height) * 1.0 / scale;
    in
    {
      output = m.name;
      x = m.x;
      y = m.y;
      w = logicalW;
      h = logicalH;
      # Native (post-transform) pixel size the file must have.
      outW = if rotated then m.height else m.width;
      outH = if rotated then m.width else m.height;
    };

  monitorInfos = map mkMonitorInfo monitors;

  minOf = f: list: if list == [ ] then 0.0 else lib.foldl' (acc: m: lib.min acc (f m)) (f (builtins.head list)) list;
  maxOf = f: list: if list == [ ] then 0.0 else lib.foldl' (acc: m: lib.max acc (f m)) (f (builtins.head list)) list;

  minX = minOf (m: m.x) monitorInfos;
  minY = minOf (m: m.y) monitorInfos;
  canvasW = round (maxOf (m: m.x + m.w) monitorInfos - minX);
  canvasH = round (maxOf (m: m.y + m.h) monitorInfos - minY);

  autoSegments = lib.imap1
    (i: m: {
      inherit (m) output outW outH;
      index = i;
      x = round (m.x - minX);
      y = round (m.y - minY);
      w = round m.w;
      h = round m.h;
    })
    monitorInfos;

  manualSegments = lib.imap1
    (i: seg: seg // { index = i; outW = null; outH = null; })
    wpCfg.span.segments;

  spanSegments = if wpCfg.span.segments != [ ] then manualSegments else autoSegments;

  videoExts = [ "mp4" "webm" "mkv" "mov" "avi" "m4v" ];
  sourceExt = lib.toLower (lib.last (lib.splitString "." (baseNameOf (toString wpCfg.span.source))));
  spanFormat =
    if wpCfg.span.format != "auto" then wpCfg.span.format
    else if lib.elem sourceExt videoExts then "video"
    else "image";

  # Scale the source onto the canvas, then crop one monitor.
  fitFilter =
    if wpCfg.span.fit == "stretch" then
      "scale=${toString canvasW}:${toString canvasH}"
    else if wpCfg.span.fit == "contain" then
      "scale='min(${toString canvasW}/iw,${toString canvasH}/ih)*iw':'min(${toString canvasW}/iw,${toString canvasH}/ih)*ih'"
      + ",pad=${toString canvasW}:${toString canvasH}:(ow-iw)/2:(oh-ih)/2:color=black"
    else
      "scale='max(${toString canvasW}/iw,${toString canvasH}/ih)*iw':'max(${toString canvasW}/iw,${toString canvasH}/ih)*ih'"
      + ",crop=${toString canvasW}:${toString canvasH}:(iw-${toString canvasW})/2:(ih-${toString canvasH})/2";

  spanFilter = seg:
    fitFilter
    + ",crop=${toString seg.w}:${toString seg.h}:${toString seg.x}:${toString seg.y}"
    + lib.optionalString (seg.outW != null) ",scale=${toString seg.outW}:${toString seg.outH}"
    # H.264 needs even dimensions; harmless for PNG.
    + lib.optionalString (spanFormat == "video") ",scale=trunc(iw/2)*2:trunc(ih/2)*2";

  spanOutExt = if spanFormat == "video" then "mp4" else "png";
  spanOutName = seg: "${toString seg.index}-${seg.output}.${spanOutExt}";

  spanCodecArgs =
    if spanFormat == "video" then
      "-c:v libx264 -preset medium -crf 18 -an -pix_fmt yuv420p -movflags +faststart"
    else
      "-frames:v 1";

  mkSpanCmd = seg:
    ''ffmpeg -loglevel error -i ${lib.escapeShellArg "${wpCfg.span.source}"} -vf ${lib.escapeShellArg (spanFilter seg)} ${spanCodecArgs} -y "$out/${spanOutName seg}"'';

  spanDerivation = pkgs.runCommand "hyprland-wallpapers-span"
    {
      nativeBuildInputs = [ pkgs.ffmpeg ];
    } ''
    mkdir -p "$out"
    ${lib.concatStringsSep "\n" (map mkSpanCmd spanSegments)}
  '';

  spanImages = map
    (seg: {
      inherit (seg) output;
      path = "${spanDerivation}/${spanOutName seg}";
    })
    spanSegments;

  # Use span-generated images if enabled, otherwise user-configured images
  images = if spanEnabled then spanImages else wpCfg.images;
  hasImages = images != [ ];

  # Publish the effective list so hosts/tests can inspect what is applied.
  resolvedImagesConfig = {
    my.desktop.hyprland.wallpapers.resolvedImages =
      if cfg.enable && wpCfg.enable then images else [ ];
    my.desktop.hyprland.wallpapers.span.package =
      if cfg.enable && wpCfg.enable && spanEnabled then spanDerivation else null;
  };

  # ── hyprpaper backend ──────────────────────────────────────────────────
  hyprpaperConf =
    let
      targets =
        if hasImages then
          lib.flatten
            (builtins.map
              (img:
                if img.output != null then [{ inherit (img) path; output = img.output; }]
                else map (m: { path = img.path; output = m.output; }) monitorInfos
              )
              images) else [ ];
    in
    if targets != [ ] then
      lib.concatStringsSep "\n" (builtins.map (img: "preload = ${img.path}") images)
      + "\n" + lib.concatStringsSep "\n" (builtins.map (t: "wallpaper = ${t.output},${t.path}") targets)
    else ''
      preload  = ${pkgs.hyprpaper}/share/hyprpaper/no-wallpaper.png
      wallpaper = ,${pkgs.hyprpaper}/share/hyprpaper/no-wallpaper.png
    '';

  hyprpaperConfig = {
    environment.systemPackages = [ pkgs.hyprpaper ];
    environment.etc."xdg/hypr/hyprpaper.conf".text = hyprpaperConf;
  };

  # ── awww backend ────────────────────────────────────────────────────────
  awwwPkg = pkgs.awww;
  awwwBin = "${awwwPkg}/bin/awww";

  mkEnvValue = name: value:
    lib.optionalAttrs (value != null) { "${name}" = toString value; };

  awwwEnvironment = lib.mkMerge [
    (mkEnvValue "AWWW_TRANSITION" wpCfg.settings.awww.transitionType)
    (mkEnvValue "AWWW_TRANSITION_STEP" wpCfg.settings.awww.transitionStep)
    (mkEnvValue "AWWW_TRANSITION_FPS" wpCfg.settings.awww.transitionFps)
  ] // lib.optionalAttrs (wpCfg.settings.awww.transitionAngle != null) {
    "AWWW_TRANSITION_ANGLE" = toString wpCfg.settings.awww.transitionAngle;
  };

  awwwImgCmds = builtins.map
    (img:
      let
        outputFlag = lib.optionalString (img.output != null) "-o ${lib.escapeShellArg img.output}";
      in
      "${awwwBin} img ${outputFlag} ${lib.escapeShellArg img.path}"
    )
    images;

  awwwConfig = {
    environment.systemPackages = [ awwwPkg ];

    systemd.user.services.awww-daemon = {
      description = "awww animated wallpaper daemon for Wayland";
      documentation = [ "https://codeberg.org/LGFae/awww" ];
      wantedBy = [ "hyprland-session.target" ];
      partOf = [ "hyprland-session.target" ];
      after = [ "hyprland-session.target" ];

      serviceConfig = {
        Type = "simple";
        ExecStart = "${awwwPkg}/bin/awww-daemon ${lib.escapeShellArgs wpCfg.settings.awww.daemonArgs}";
        Restart = "on-failure";
        RestartSec = 2;
      };

      environment = lib.mkIf (hasImages) awwwEnvironment;
      postStart = lib.mkIf (hasImages) (lib.concatStringsSep "\n" awwwImgCmds);
    };
  };

  # ── mpvpaper backend ────────────────────────────────────────────────────
  mpvpaperPkg = pkgs.mpvpaper;

  mkMpvpaperCmd = img:
    let
      out = if img.output != null then img.output else "ALL";
      mpvOpts = lib.escapeShellArg (wpCfg.settings.mpvpaper.mpvOptions
        + lib.optionalString (wpCfg.settings.mpvpaper.ipcSocket != null)
        " input-ipc-server=${wpCfg.settings.mpvpaper.ipcSocket}.${out}");
    in
    "${mpvpaperPkg}/bin/mpvpaper -o ${mpvOpts} ${out} ${lib.escapeShellArg img.path} &";

  mpvpaperCmd =
    if hasImages then
      (lib.concatStringsSep "\n" (builtins.map mkMpvpaperCmd images))
      + "\nwait"
    else
      "sleep infinity";

  mpvpaperConfig = {
    environment.systemPackages = [ mpvpaperPkg ];

    systemd.user.services.mpvpaper = lib.mkIf (hasImages) {
      description = "mpvpaper video wallpaper daemon for Wayland";
      documentation = [ "https://github.com/GhostNaN/mpvpaper" ];
      wantedBy = [ "hyprland-session.target" ];
      partOf = [ "hyprland-session.target" ];
      after = [ "hyprland-session.target" ];

      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.bash}/bin/bash -c ${lib.escapeShellArg mpvpaperCmd}";
        Restart = "on-failure";
        RestartSec = 5;
      };
    };
  };

  # ── waypaper backend ───────────────────────────────────────────────────
  waypaperPkg = pkgs.waypaper;

  waypaperBackendPackages = {
    swaybg = pkgs.swaybg;
    hyprpaper = pkgs.hyprpaper;
    awww = pkgs.awww;
    mpvpaper = pkgs.mpvpaper;
    wallutils = pkgs.wallutils;
    feh = pkgs.feh;
    xwallpaper = pkgs.xwallpaper;
  };

  waypaperFolder =
    if wpCfg.settings.waypaper.folder != null
    then wpCfg.settings.waypaper.folder
    else wpCfg.wallpaperDir;

  waypaperIni = lib.concatStringsSep "\n" (
    [
      "[Settings]"
      "backend = ${wpCfg.settings.waypaper.backend}"
      "folder = ${waypaperFolder}"
      "fill = ${wpCfg.settings.waypaper.fillOption}"
    ]
    ++ lib.optional (hasImages)
      "image = ${(builtins.head images).path}"
  );

  waypaperConfig = {
    environment.systemPackages = [ waypaperPkg ]
      ++ lib.optional (waypaperBackendPackages ? ${wpCfg.settings.waypaper.backend})
      waypaperBackendPackages.${wpCfg.settings.waypaper.backend}
      ++ wpCfg.settings.waypaper.extraPackages;
    environment.etc."waypaper/config.ini".text = waypaperIni;
  };
  # ── swaybg backend ────────────────────────────────────────────────────
  # One swaybg process per output (swaybg takes a single -o). The service is
  # owned here so span-generated crops are used too; core/config.nix no longer
  # starts swaybg from an exec-once line.
  mkSwaybgInstance = img:
    let
      output = lib.optionalString (img.output != null) "-o ${lib.escapeShellArg img.output} ";
    in
    "${pkgs.swaybg}/bin/swaybg ${output}-i ${lib.escapeShellArg img.path} -m fill";

  swaybgScript =
    lib.concatMapStrings (img: mkSwaybgInstance img + " &\n") images
    + "wait\n";

  swaybgConfig = {
    environment.systemPackages = [ pkgs.swaybg ];

    systemd.user.services.swaybg = lib.mkIf hasImages {
      description = "swaybg static wallpaper daemon for Wayland";
      documentation = [ "https://github.com/swaywm/swaybg" ];
      wantedBy = [ "hyprland-session.target" ];
      partOf = [ "hyprland-session.target" ];
      after = [ "hyprland-session.target" ];

      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.bash}/bin/bash -c ${lib.escapeShellArg swaybgScript}";
        Restart = "on-failure";
        RestartSec = 2;
      };
    };
  };
in
{
  config = lib.mkMerge [
    {
      assertions = [
        {
          assertion = !(cfg.enable && wpCfg.span.enable) || monitorInfos != [ ];
          message = "wallpapers.span: no enabled monitors to crop to (check my.monitors).";
        }
        {
          assertion = !(cfg.enable && wpCfg.span.enable) || lib.all (m: (m.scale or 1) > 0) monitors;
          message = "wallpapers.span: every my.monitors entry needs a positive scale.";
        }
        {
          assertion = !(cfg.enable && wpCfg.span.enable) || wpCfg.backend != "waypaper";
          message = "wallpapers.span: the waypaper backend restores a single image and cannot apply per-output segments; use hyprpaper, awww, swaybg or mpvpaper.";
        }
        {
          assertion = !(cfg.enable && wpCfg.span.enable) || spanFormat == "image" || wpCfg.backend == "mpvpaper";
          message = "wallpapers.span: a video source needs the mpvpaper backend; hyprpaper/swaybg/awww need an image.";
        }
      ];
    }
    resolvedImagesConfig
    (lib.mkIf (cfg.enable && wpCfg.enable && wpCfg.backend == "hyprpaper") hyprpaperConfig)
    (lib.mkIf (cfg.enable && wpCfg.enable && wpCfg.backend == "awww") awwwConfig)
    (lib.mkIf (cfg.enable && wpCfg.enable && wpCfg.backend == "mpvpaper") mpvpaperConfig)
    (lib.mkIf (cfg.enable && wpCfg.enable && wpCfg.backend == "waypaper") waypaperConfig)
    (lib.mkIf (cfg.enable && wpCfg.enable && wpCfg.backend == "swaybg") swaybgConfig)
  ];
}
