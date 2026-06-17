{ config, lib, pkgs, ... }:
let
  cfg = config.my.desktop.hyprland;
  wpCfg = cfg.wallpapers;

  # ── Span: auto-scale + crop a source across all monitors ───────────────
  spanEnabled = wpCfg.span.enable;
  monitors = config.my.monitors or [ ];

  # Logical monitor info (accounting for portrait transforms)
  mkMonitorInfo = m: let
    isPortrait = (m.transform or 0) == 1 || (m.transform or 0) == 3;
    logicW = if isPortrait then m.height else m.width;
    logicH = if isPortrait then m.width else m.height;
    rot = if (m.transform or 0) == 1 then 270
      else if (m.transform or 0) == 3 then 90
      else if (m.transform or 0) == 2 then 180
      else 0;
  in {
    output = m.name;
    x = m.x;
    y = m.y;
    w = logicW;
    h = logicH;
    rotate = rot;
  };

  monitorInfos = map mkMonitorInfo monitors;

  # Canvas: bounding box of all monitors in logical coords
  canvasW = lib.foldl' lib.max 0 (map (m: m.x + m.w) monitorInfos);
  canvasH = lib.foldl' lib.max 0 (map (m: m.y + m.h) monitorInfos);

  # Use explicit segments if provided, otherwise auto-derive from monitors
  spanSegments = if wpCfg.span.segments != [ ] then
    lib.imap1 (i: seg: { inherit (seg) output x y w h rotate; index = i; }) wpCfg.span.segments
  else
    lib.imap1 (i: m: m // { index = i; }) monitorInfos;

  mkRotateFilter = rot:
    if rot == 0 then ""
    else if rot == 90 then ",transpose=1"
    else if rot == 270 then ",transpose=2"
    else if rot == 180 then ",transpose=1,transpose=1"
    else "";

  # Ffmpeg filter that scales source to fill the canvas (fit mode),
  # then crops each monitor's portion at the correct position.
  # Uses ffmpeg expressions (iw/ih) so we never need to probe source dims.
  mkSpanFilter = seg:
    let
      scaleCrop = if wpCfg.span.fit == "stretch" then
        "scale=${toString canvasW}:${toString canvasH}"
      else if wpCfg.span.fit == "contain" then
        "scale='min(${toString canvasW}/iw,${toString canvasH}/ih)*iw':'min(${toString canvasW}/iw,${toString canvasH}/ih)*ih'"
      else
        "scale='max(${toString canvasW}/iw,${toString canvasH}/ih)*iw':'max(${toString canvasW}/iw,${toString canvasH}/ih)*ih'";

      centerCrop = if wpCfg.span.fit == "stretch" then ""
        else ",crop=${toString canvasW}:${toString canvasH}:(iw-${toString canvasW})/2:(ih-${toString canvasH})/2";

      monitorCrop = ",crop=${toString seg.w}:${toString seg.h}:${toString seg.x}:${toString seg.y}";
    in
      "${scaleCrop}${centerCrop}${monitorCrop}${mkRotateFilter seg.rotate}";

  mkFfmpegCmd = seg:
    let
      filter = mkSpanFilter seg;
      outFile = "segment-${toString seg.index}-${seg.output}.mp4";
    in
    ''ffmpeg -i ${lib.escapeShellArg wpCfg.span.source} -filter:v ${lib.escapeShellArg filter} -c:v libx264 -an -pix_fmt yuv420p -y "$out/${outFile}"'';

  spanDerivation = pkgs.runCommandLocal "wallpapers-span" {
    nativeBuildInputs = [ pkgs.ffmpeg ];
    buildInputs = [ ];
  } ''
    mkdir -p "$out"
    ${lib.concatStringsSep "\n" (map mkFfmpegCmd spanSegments)}
  '';

  spanImages = map (seg:
    {
      output = seg.output;
      path = "${spanDerivation}/segment-${toString seg.index}-${seg.output}.mp4";
    }
  ) spanSegments;

  # Use span-generated images if enabled, otherwise user-configured images
  images = if spanEnabled then spanImages else wpCfg.images;
  hasImages = images != [ ];

  # ── hyprpaper backend ──────────────────────────────────────────────────
  hyprpaperConf = let
    targets = if hasImages then lib.flatten (builtins.map (img:
      if img.output != null then [{ inherit (img) path; output = img.output; }]
      else map (m: { path = img.path; output = m.output; }) monitorInfos
    ) images) else [];
  in if targets != [] then
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

  awwwImgCmds = builtins.map (img:
    let
      outputFlag = lib.optionalString (img.output != null) "-o ${lib.escapeShellArg img.output}";
    in
    "${awwwBin} img ${outputFlag} ${lib.escapeShellArg img.path} --no-cache"
  ) images;

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

  mpvpaperCmd = if hasImages then
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
    swaybg     = pkgs.swaybg;
    hyprpaper  = pkgs.hyprpaper;
    awww       = pkgs.awww;
    mpvpaper   = pkgs.mpvpaper;
    wallutils  = pkgs.wallutils;
    feh        = pkgs.feh;
    xwallpaper = pkgs.xwallpaper;
  };

  waypaperFolder = if wpCfg.settings.waypaper.folder != null
    then wpCfg.settings.waypaper.folder
    else wpCfg.wallpaperDir;

  waypaperIni = lib.concatStringsSep "\n" (
    [ "[Settings]"
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
  swaybgConfig = {
    environment.systemPackages = [ pkgs.swaybg ];
  };
in
{
  config = lib.mkMerge [
    (lib.mkIf (cfg.enable && wpCfg.enable && wpCfg.backend == "hyprpaper") hyprpaperConfig)
    (lib.mkIf (cfg.enable && wpCfg.enable && wpCfg.backend == "awww") awwwConfig)
    (lib.mkIf (cfg.enable && wpCfg.enable && wpCfg.backend == "mpvpaper") mpvpaperConfig)
    (lib.mkIf (cfg.enable && wpCfg.enable && wpCfg.backend == "waypaper") waypaperConfig)
    (lib.mkIf (cfg.enable && wpCfg.enable && wpCfg.backend == "swaybg") swaybgConfig)
  ];
}
