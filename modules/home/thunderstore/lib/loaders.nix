# =============================================================================
# loaders.nix — the ThunderStore loader model
# =============================================================================
# The ecosystem schema (https://thunderstore.io/api/experimental/schema/dev/latest/)
# describes a game with a `packageLoader` (one of 13 values) plus `installRules`.
# Those two together are NOT enough to install a mod, because upstream splits the
# loaders into two families:
#
#   1. install-rule-driven (7 of 13): bepinex, bepisloader, godotml, melonloader,
#      northstar, shimloader, umm — a generic plugin installer walks the zip and
#      routes each file by the game's `installRules` (trackingMethod + route +
#      defaultFileExtensions).
#
#   2. hardcoded-plugin (6 of 13): gdweave, lovely, none, recursive-melonloader,
#      return-of-modding, rivet — these ignore `installRules` (which is `[]` for
#      them upstream) and have bespoke payload/mod destinations.
#
# This file is the single source of truth for family 2 and for the per-loader
# payload rules of family 1. `lib/route.py` consumes it as JSON (rendered by
# `lib/pack.nix`), so the routing table is typed/reviewable Nix rather than
# stringly-typed Python.
#
# Destinations, relative to the discovered game root unless stated:
#   gameRoot      the Steam install dir (default; what BepInEx/MelonLoader want)
#   dataBinaries  <dataFolderName>/Binaries/Win64/ — Unreal/shimloader only
#   releaseDir    <installDir>/Release/ — Rivet's version.dll hook only
#
# Sources: ecosystem-schema games/src/models.ts (loader enum + ModmanInstallRule),
# ecosystem-schema games/misc/modloader-packages.yml (loader pack rootFolder),
# r2modmanPlus src/r2mm/manager/*Installer.ts (per-loader payload + mod routes),
# tcli-rust crates/tcli/src/game/registry.rs (game/data/exe resolution).
# =============================================================================

{ lib }:

let
  inherit (lib) mapAttrs;

  # A payload rule: copy `<from>` (a glob relative to the loader pack root, after
  # rootFolder stripping) to `<to>` (relative to the destination). `exclude`
  # drops base metadata files that ThunderStore ships inside every pack.
  copy = from: to: { inherit from to; };
  exclude = [ "manifest.json" "readme.md" "README.md" "icon.png" ];

  # "Everything in the pack except ThunderStore's base metadata files."
  everything = {
    copies = [ (copy "*" "") ];
    inherit exclude;
  };

in
rec {

  # Loaders whose mod layout is described by the game's installRules.
  installRuleDriven = [
    "bepinex"
    "bepisloader"
    "godotml"
    "melonloader"
    "northstar"
    "shimloader"
    "umm"
  ];

  # Every loader the ecosystem can express, and whether we can route it.
  supported = [
    "bepinex"
    "bepisloader"
    "godotml"
    "melonloader"
    "northstar"
    "shimloader"
    "umm"
    "gdweave"
    "lovely"
    "none"
    "recursive-melonloader"
    "return-of-modding"
    "rivet"
  ];

  # Loaders that hard-require a non-empty dataFolderName
  # (ecosystem-schema games/src/schema/packageLoaders.ts `requiresDataFolder`).
  requiresDataFolder = [
    "bepinex"
    "shimloader"
    "umm"
    "recursive-melonloader"
  ];

  # Destinations a payload/mod tree may be routed to, resolved relative to the
  # discovered game root at install time by lib/install.sh.
  destinations = [
    "gameRoot"
    "dataBinaries"
    "releaseDir"
  ];

  # Per-loader model.
  #
  #   description      human summary (surfaced by thunderstore-game-info)
  #   family           "installRules" | "hardcoded"
  #   payload          how the loader PACK is unpacked into the game
  #   payloadDest      one of `destinations`
  #   mods             default mod destinations, used only when family=hardcoded
  #   modTracking      default trackingMethod for hardcoded loaders
  #   nativeNote       set when upstream skips copying on Linux/macOS
  byLoader = {
    bepinex = {
      description = "BepInEx 5/6 (Unity mono + IL2CPP). The loaders you meet most.";
      family = "installRules";
      payload = everything;
      payloadDest = "gameRoot";
      nativeNote = "upstream copies nothing on native Linux/darwin; we always copy (Proton/Windows)";
    };

    bepisloader = {
      description = "BepInEx fork for Resonite (Resonite/Renderer/BepInEx/plugins).";
      family = "installRules";
      payload = everything;
      payloadDest = "gameRoot";
      mods = [
        {
          route = "Renderer/BepInEx/plugins";
          defaultFileExtensions = [ ".dll" ];
          trackingMethod = "subdir";
          isDefaultLocation = true;
        }
      ];
    };

    melonloader = {
      description = "MelonLoader (legacy, whole-pack install).";
      family = "installRules";
      payload = everything;
      payloadDest = "gameRoot";
    };

    recursive-melonloader = {
      description = "MelonLoader >= 0.7.0: only MelonLoader/ + version.dll are installed.";
      family = "hardcoded";
      payload = {
        exclude = exclude;
        copies = [
          (copy "MelonLoader/**" "MelonLoader")
          (copy "version.dll" "version.dll")
        ];
      };
      payloadDest = "gameRoot";
      mods = [
        {
          route = "Mods";
          defaultFileExtensions = [ ];
          trackingMethod = "subdir";
          isDefaultLocation = true;
        }
        {
          route = "UserData";
          defaultFileExtensions = [ ];
          trackingMethod = "subdir";
          isDefaultLocation = false;
        }
      ];
      modTracking = "subdir";
    };

    umm = {
      description = "Unity Mod Manager (Doorstop payload: winhttp.dll, doorstop_config.ini).";
      family = "installRules";
      payload = {
        exclude = exclude;
        copies = [
          (copy "UMM/Core/**" "UMM/Core")
          (copy "doorstop_config.ini" "doorstop_config.ini")
          (copy "winhttp.dll" "winhttp.dll")
          (copy ".doorstop_version" ".doorstop_version")
          (copy "doorstop_libs/**" "doorstop_libs")
          (copy "run_umm.sh" "run_umm.sh")
        ];
      };
      payloadDest = "gameRoot";
    };

    shimloader = {
      description = "Unreal shimloader (UE4SS). Payload lives in the Unreal binaries dir.";
      family = "installRules";
      payload = {
        exclude = exclude;
        copies = [
          (copy "dwmapi.dll" "dwmapi.dll")
          (copy "UE4SS/ue4ss.dll" "ue4ss.dll")
          (copy "UE4SS/UE4SS-settings.ini" "UE4SS-settings.ini")
          (copy "UE4SS/Mods/**" "shimloader/mod")
        ];
        mkdirs = [ "shimloader/cfg" ];
      };
      # ue4ss.dll + friends sit next to the Unreal binary, not the game root.
      payloadDest = "dataBinaries";
    };

    northstar = {
      description = "Northstar (Titanfall 2 / Apex). Mods live in R2Northstar/mods.";
      family = "hardcoded";
      payload = everything;
      payloadDest = "gameRoot";
      mods = [
        {
          route = "R2Northstar/mods";
          defaultFileExtensions = [ ];
          trackingMethod = "state";
          isDefaultLocation = true;
        }
      ];
      modTracking = "state";
    };

    godotml = {
      description = "GodotModLoader. Mods are re-zipped as <name>.ts.zip.";
      family = "hardcoded";
      payload = {
        exclude = exclude;
        copies = [
          (copy "addons/mod_loader/**" "addons/mod_loader")
          (copy "addons/JSON_Schema_Validator/**" "addons/JSON_Schema_Validator")
        ];
      };
      payloadDest = "gameRoot";
      mods = [
        {
          route = "mods";
          defaultFileExtensions = [ ".gd" ".ts" ];
          trackingMethod = "package-zip";
          isDefaultLocation = true;
        }
      ];
      modTracking = "package-zip";
    };

    gdweave = {
      description = "GDWeave (WEBFISHING). winmm.dll + GDWeave/ payload.";
      family = "hardcoded";
      payload = {
        exclude = exclude;
        copies = [
          (copy "winmm.dll" "winmm.dll")
          (copy "GDWeave/**" "GDWeave")
        ];
      };
      payloadDest = "gameRoot";
      mods = [
        {
          route = "GDWeave/mods";
          defaultFileExtensions = [ ".dll" ];
          trackingMethod = "subdir";
          isDefaultLocation = true;
        }
      ];
      modTracking = "subdir";
    };

    lovely = {
      description = "Lovely (Luigi's Mansion). version.dll + lovely/ payload.";
      family = "hardcoded";
      payload = {
        exclude = exclude;
        copies = [
          (copy "version.dll" "version.dll")
          (copy "lovely/**" "mods")
        ];
      };
      payloadDest = "gameRoot";
      mods = [
        {
          route = "mods";
          defaultFileExtensions = [ ".lua" ];
          trackingMethod = "subdir";
          isDefaultLocation = true;
        }
      ];
      modTracking = "subdir";
    };

    "return-of-modding" = {
      description = "Return of Modding (Hades II / Risk of Rain Returns).";
      family = "hardcoded";
      payload = everything;
      payloadDest = "gameRoot";
      mods = [
        {
          route = "ReturnOfModding/plugins";
          defaultFileExtensions = [ ".dll" ];
          trackingMethod = "subdir-no-flatten";
          isDefaultLocation = true;
        }
        {
          route = "ReturnOfModding/plugins_data";
          defaultFileExtensions = [ ];
          trackingMethod = "subdir-no-flatten";
          isDefaultLocation = false;
        }
        {
          route = "ReturnOfModding/config";
          defaultFileExtensions = [ ];
          trackingMethod = "subdir-no-flatten";
          isDefaultLocation = false;
        }
      ];
      modTracking = "subdir-no-flatten";
    };

    rivet = {
      description = "Rivet. version.dll is a Release/-dir hook; mods go in Rivet/Mods.";
      family = "hardcoded";
      payload = {
        exclude = exclude;
        copies = [
          (copy "version.dll" "version.dll")
          (copy "Rivet.ini" "Rivet.ini")
          (copy "Rivet/**" "Rivet")
        ];
      };
      payloadDest = "gameRoot";
      # Rivet resolves version.dll from the Unreal Release/ directory.
      payloadExtraDest = [
        {
          from = "version.dll";
          to = "version.dll";
          dest = "releaseDir";
        }
      ];
      mods = [
        {
          route = "Rivet/Mods";
          defaultFileExtensions = [ ".dll" ];
          trackingMethod = "subdir";
          isDefaultLocation = true;
        }
      ];
      modTracking = "subdir";
    };

    none = {
      description = "No loader: mods are copied verbatim into mods/<ModName>/.";
      family = "hardcoded";
      payload = {
        exclude = exclude;
        copies = [ ];
        mkdirs = [ ];
      };
      payloadDest = "gameRoot";
      mods = [
        {
          route = "mods";
          defaultFileExtensions = [ ];
          trackingMethod = "subdir";
          isDefaultLocation = true;
        }
      ];
      modTracking = "subdir";
    };
  };

  # The routing table as plain JSON for lib/route.py (one source of truth).
  toJson = {
    inherit installRuleDriven supported requiresDataFolder destinations;
    byLoader = mapAttrs
      (_: loader: {
        description = loader.description;
        family = loader.family;
        payloadDest = loader.payloadDest;
        # Only the hardcoded-plugin loaders carry `mods`/`modTracking`; the
        # install-rule-driven ones read these from the game's installRules.
        mods = loader.mods or [ ];
        modTracking = loader.modTracking or null;
        nativeNote = loader.nativeNote or null;
        payload = loader.payload or {
          exclude = exclude;
          copies = [ ];
          mkdirs = [ ];
        };
        payloadExtraDest = loader.payloadExtraDest or [ ];
      })
      byLoader;
  };

  # Guard: every loader the ecosystem can express must be modelled, otherwise a
  # pack for that game would silently install nothing.
  modelled = mapAttrs (_: loader: loader.family) byLoader;
  modelledLoaders = builtins.attrNames byLoader;
}
