{ config, lib, pkgs, ... }:

let
  cfg = config.my.programs.obs-studio;
  profilesDir = "${config.home.homeDirectory}/.config/obs-studio/basic/profiles";
in
{
  config = lib.mkIf cfg.enable {
    programs.obs-studio = {
      enable = true;
      inherit (cfg) package plugins;
    };

    # OBS reads its recording paths only at startup, so patching the profile on
    # activation takes effect the next time OBS launches. crudini edits the
    # existing keys in place, preserving everything else in basic.ini.
    home.activation.obsStudioRecordingPath = lib.mkIf (cfg.recordingPath != null) (
      lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        PROFILES_DIR="${profilesDir}"

        if [ ! -d "$PROFILES_DIR" ] || [ -z "$(ls -A "$PROFILES_DIR" 2>/dev/null)" ]; then
          mkdir -p "$PROFILES_DIR/Untitled"
          cat > "$PROFILES_DIR/Untitled/basic.ini" <<'EOF'
        [General]
        Name=Untitled

        [SimpleOutput]
        FilePath=${cfg.recordingPath}

        [AdvOut]
        RecFilePath=${cfg.recordingPath}
        FFFilePath=${cfg.recordingPath}
        EOF
        fi

        for profile in "$PROFILES_DIR"/*/basic.ini; do
          [ -e "$profile" ] || continue
          ${pkgs.crudini}/bin/crudini --set "$profile" SimpleOutput FilePath "${cfg.recordingPath}"
          ${pkgs.crudini}/bin/crudini --set "$profile" AdvOut RecFilePath "${cfg.recordingPath}"
          ${pkgs.crudini}/bin/crudini --set "$profile" AdvOut FFFilePath "${cfg.recordingPath}"
        done
      ''
    );
  };
}
