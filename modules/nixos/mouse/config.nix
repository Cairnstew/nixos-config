{ config, lib, pkgs, flake, ... }:
let
  cfg = config.my.hardware.mouse;
  inherit (flake) inputs;

  # Build the CLI binary so we can reference it in the systemd service
  # derivation with a deterministic store path.
  maccel-cli = pkgs.rustPlatform.buildRustPackage {
    pname = "maccel-cli";
    version = (builtins.fromTOML (builtins.readFile "${inputs.maccel}/cli/Cargo.toml")).package.version;
    src = inputs.maccel;
    cargoLock.lockFile = "${inputs.maccel}/Cargo.lock";
    cargoBuildFlags = [ "--bin" "maccel" ];
    doCheck = false;
  };

  # Maps Nix option names to 'maccel set param' CLI names for runtime apply.
  paramNameMap = {
    sensMultiplier = "sens-mult";
    yxRatio = "yx-ratio";
    inputDpi = "input-dpi";
    angleRotation = "angle-rotation";
    acceleration = "accel";
    offset = "offset-linear";
    outputCap = "output-cap";
    decayRate = "decay-rate";
    limit = "limit";
    gamma = "gamma";
    smooth = "smooth";
    motivity = "motivity";
    syncSpeed = "sync-speed";
  };

  # Generate the shell commands that apply all configured parameters to the
  # running kernel module via sysfs.
  applyParamsCmds =
    let
      p = config.hardware.maccel.parameters;
      maccelBin = "${maccel-cli}/bin/maccel";
      setParam = nixName: cliName:
        lib.optional (builtins.getAttr nixName p != null)
          "${maccelBin} set param ${cliName} ${toString (builtins.getAttr nixName p)}";
      paramCmds = lib.flatten (lib.mapAttrsToList setParam paramNameMap);
    in
    [ "${maccelBin} set mode ${p.mode}" ] ++ paramCmds;
in
{
  imports = [
    inputs.maccel.nixosModules.default
  ];

  config = lib.mkIf cfg.enable {
    hardware.maccel = {
      enable = true;
      enableCli = true;

      parameters = {
        mode = cfg.parameters.mode;
        sensMultiplier = cfg.parameters.sensMultiplier;
        yxRatio = cfg.parameters.yxRatio;
        inputDpi = cfg.parameters.inputDpi;
        angleRotation = cfg.parameters.angleRotation;
        acceleration = cfg.parameters.acceleration;
        offset = cfg.parameters.offset;
        outputCap = cfg.parameters.outputCap;
        decayRate = cfg.parameters.decayRate;
        limit = cfg.parameters.limit;
        gamma = cfg.parameters.gamma;
        smooth = cfg.parameters.smooth;
        motivity = cfg.parameters.motivity;
        syncSpeed = cfg.parameters.syncSpeed;
      };
    };

    # Runtime param application — applies the Nix-configured params to the
    # already-loaded kernel module. This is necessary because modprobe
    # options only take effect at module load time (reboot).
    systemd.services.maccel-apply-params = {
      description = "Apply maccel kernel module parameters at runtime";
      after = [ "systemd-modules-load.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig.Type = "oneshot";
      script = lib.concatStringsSep "\n" applyParamsCmds;
    };

    # GNOME integration: ensure GNOME's own acceleration is flat so the
    # kernel-level maccel curve is the only active acceleration.
    home-manager.users.${flake.config.me.username}.dconf.settings."org/gnome/desktop/peripherals/mouse" =
      lib.mkIf config.my.desktop.gnome.enable {
        accel-profile = cfg.gnome.accelProfile;
        speed = cfg.gnome.speed;
      };
  };
}
