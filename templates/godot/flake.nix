{
  description = "Godot Game Development Environment";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    # godot-mcp is a third-party MCP server (MIT, Coding-Solo/godot-mcp).
    # Pinned as a flake input so `nix flake update godot-mcp-src` bumps it
    # cleanly instead of manual hash recomputation.
    godot-mcp-src = {
      url = "github:Coding-Solo/godot-mcp";
      flake = false;
    };
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ];

      perSystem =
        { pkgs, lib, ... }:
        let
          godot-mcp = pkgs.buildNpmPackage {
            pname = "godot-mcp";
            version = "0.1.1";

            src = inputs.godot-mcp-src;

            npmDepsHash = "sha256-9F2QW8+IQiL+qZ4EXSq1pgk3DMmES8aAP3CAwL+fDfc=";

            installPhase = ''
              mkdir -p $out/bin $out/lib/node_modules/godot-mcp
              cp -r node_modules $out/lib/node_modules/godot-mcp/
              cp -r build $out/lib/node_modules/godot-mcp/
              cp package.json $out/lib/node_modules/godot-mcp/
              makeWrapper ${pkgs.nodejs}/bin/node $out/bin/godot-mcp \
                --add-flags "$out/lib/node_modules/godot-mcp/build/index.js"
            '';

            meta = {
              description = "MCP server for interfacing with the Godot game engine";
              homepage = "https://github.com/Coding-Solo/godot-mcp";
              license = lib.licenses.mit;
              platforms = lib.platforms.linux;
            };
          };

          godotPkg = pkgs.godot-mono;
          dotnetPkg = pkgs.dotnet-sdk_8;
          zedPkg = pkgs.zed-editor;
          templatesPkg = pkgs.godotPackages.export-templates-mono-bin;
          templatesDir = "${templatesPkg}/share/godot/export_templates";

          # Wraps a shell script as a Nix app.  No implicit dotnet restore/build
          # here — that belongs in the explicit `build` app and `dev` loop.
          # godot-mono --path . does NOT auto-build C# (verified 2026-07-11);
          # it loads the pre-compiled DLL from .godot/mono/temp/.
          mkGodotApp =
            name: text:
            let
              script = pkgs.writeShellApplication {
                inherit name;
                runtimeInputs = [ godotPkg dotnetPkg pkgs.mesa pkgs.vulkan-loader ];
                text = ''
                  set -e
                  export VK_ICD_FILENAMES="${pkgs.mesa}/share/vulkan/icd.d/*.json"
                  cd "$(git rev-parse --show-toplevel 2>/dev/null || echo .)"
                  ${text}
                '';
              };
            in
            {
              type = "app";
              program = "${script}/bin/${name}";
            };

          mkExportApp =
            name: platform: exportPath:
            mkGodotApp name ''
              mkdir -p "$(dirname "${exportPath}")"
              export HOME="$(mktemp -d)"
              mkdir -p "$HOME/.local/share/godot/export_templates"
              ln -sf ${templatesDir}/* "$HOME/.local/share/godot/export_templates/"
              exec godot-mono --headless --export-release "${platform}" "${exportPath}"
            '';
        in
        {
          packages.godot-mcp = godot-mcp;

          devShells.default = pkgs.mkShell {
            name = "godot-dev";

            packages = with pkgs; [
              godotPkg
              dotnetPkg
              templatesPkg
              godot-mcp
              omnisharp-roslyn    # C# LSP for Zed (resolves GodotSharp, works with .NET 8)
              watchexec           # file watcher for dev loop
              godotpcktool
              gdtoolkit_4
              gdscript-formatter
              git
              nodejs
            ];

            shellHook = ''
              if ls *.csproj 2>/dev/null && [ ! -f .godot/mono/temp/obj/project.assets.json ]; then
                dotnet restore
              fi
              echo "Godot $(godot-mono --version 2>/dev/null) | .NET $(dotnet --version 2>/dev/null)"
            '';
          };

          apps = {
            # Opens the project in Zed (no Godot editor GUI).
            # Other apps:  nix run .#build    — dotnet build only
            #              nix run .#preview  — run the game standalone
            #              nix run .#editor   — Godot editor GUI
            #              nix run .#dev      — auto-rebuild + relaunch on save
            #              nix run .#scene -- myscene.tscn  — run specific scene
            default = {
              type = "app";
              program = "${pkgs.writeShellApplication {
                name = "godot-zed";
                runtimeInputs = [ godotPkg dotnetPkg zedPkg ];
                text = ''
                  cd "$(git rev-parse --show-toplevel 2>/dev/null || echo .)"
                  if ls *.csproj 2>/dev/null; then dotnet restore; fi
                  exec zeditor .
                '';
                meta.description = "Open project in Zed editor";
              }}/bin/godot-zed";
            };

            # Build C# project only (incremental via MSBuild's up-to-date check).
            # ~2s when nothing changed — comparable to Godot editor's build step.
            build = mkGodotApp "godot-build" ''
              if ls *.csproj 2>/dev/null; then dotnet build --no-restore; fi
            '';

            # Launch project standalone (no editor GUI).
            # Display driver: auto-detected (Wayland on Hyprland, X11 fallback).
            #   Godot 4.6 Wayland DisplayServer is mature — clipboard, file
            #   dialogs, window management are all functional.
            # Rendering driver: auto-detected (Vulkan w/ RADV on Navi23
            #   confirmed 2026-07-11; OpenGL 4.6 Core fallback via radeonsi).
            #   Remove these only after verifying your GPU + compositor
            #   combo — re-add only the specific flag that breaks, not both.
            preview = mkGodotApp "godot-preview" ''
              exec godot-mono --path .
            '';

            # Full Godot editor GUI (for scene/resource editing that requires it).
            editor = mkGodotApp "godot-editor" ''
              exec godot-mono --editor --path .
            '';

            # Run a specific scene file from the command line.
            scene = mkGodotApp "godot-scene" ''
              exec godot-mono --path . "$@"
            '';

            # Dev loop: watchexec rebuilds C# and relaunches on file change.
            # Watches the entire project directory (excluding .godot/ build cache).
            # This is a fast-restart loop, not true hot-reload — C# assemblies are
            # only loaded as collectible when the editor is running (Godot PR #67511).
            # Cycle time is ~3-5s for a code change.
            dev = mkGodotApp "godot-dev" ''
              exec ${pkgs.watchexec}/bin/watchexec \
                --watch . --exts cs,tscn --ignore .godot/ \
                --restart \
                -- sh -c "dotnet build --no-restore && exec godot-mono --path ."
            '';

            export-linux = mkExportApp "godot-export-linux" "Linux/X11" "./exports/game.x86_64";
            export-windows = mkExportApp "godot-export-windows" "Windows Desktop" "./exports/game.exe";
            export-macos = mkExportApp "godot-export-macos" "macOS" "./exports/game.dmg";
          };
        };
    };
}
