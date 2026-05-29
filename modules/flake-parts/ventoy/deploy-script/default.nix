{ pkgs, lib
, ventoyJson       # store path to ventoy.json
, grubConfig ? null # optional ventoy_grub.cfg
, isoMappings ? []  # list of "source|target|hash"
, fileMappings ? [] # list of "source|target|hash"
, device ? ""
, mountPoint ? "/mnt/ventoy"
, buildInstallerIso ? false
, installerIso ? null # store path to pre-built installer ISO
, secureBoot ? false
, gpt ? false
, label ? "Ventoy"
, reserveSizeMb ? null
}:
let
  script = ./ventoy-deploy.sh;
in
pkgs.writeShellScriptBin "ventoy-deploy" ''
  set -euo pipefail

  # ── Nix-derived defaults ───────────────────────────────────────────
  export VENTOY_JSON='${ventoyJson}'
  ${lib.optionalString (grubConfig != null) "export GRUB_CFG='${grubConfig}'"}
  export ISO_MAPPINGS=(
    ${lib.concatStringsSep "\n          " isoMappings}
  )
  export FILE_MAPPINGS=(
    ${lib.concatStringsSep "\n          " fileMappings}
  )
  export DEFAULT_DEVICE="${device}"
  export MOUNT_POINT="${mountPoint}"
  export BUILD_INSTALLER_ISO="${if buildInstallerIso then "1" else "0"}"
  ${lib.optionalString (installerIso != null) "export INSTALLER_ISO='${installerIso}'"}
  export SECURE_BOOT="${if secureBoot then "1" else "0"}"
  export GPT="${if gpt then "1" else "0"}"
  export LABEL="${label}"
  ${lib.optionalString (reserveSizeMb != null) "export RESERVE_SIZE_MB='${toString reserveSizeMb}'"}

  # ── Execute the deploy logic ───────────────────────────────────────
  . ${script}
  main "$@"
''
