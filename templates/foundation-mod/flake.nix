{
  description = "Foundation Game Mod Development Environment";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs = inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" "x86_64-darwin" ];

      perSystem = { pkgs, ... }: {
        devShells.default = pkgs.mkShell {
          name = "foundation-mod-dev";

          packages = with pkgs; [
            lua
            luaPackages.luacheck
            lua-language-server
            jq
            rsync
            inotify-tools
          ];

          GAME_MODS_DIR = "$HOME/Documents/Polymorph Games/Foundation/mods";

          shellHook = let
            inotifyBin = "${pkgs.inotify-tools}/bin/inotifywait";
            luaBin = "${pkgs.lua}/bin/lua";
          in ''
            echo ""
            echo "  $(printf '\xE2\x95\x94\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x97')"
            echo "  $(printf '\xE2\x95\x91')     Foundation Mod Development Shell         $(printf '\xE2\x95\x91')"
            echo "  $(printf '\xE2\x95\x9A\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x9D')"
            echo ""
            echo "  Lua:        $(lua -v 2>&1)"
            echo "  Luacheck:   $(luacheck --version 2>&1)"
            echo "  LSP:        $(lua-language-server --version 2>&1)"
            echo ""

            install-mod() {
              local name
              name=$(jq -r '.Name' mod.json 2>/dev/null | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
              [[ -z "$name" || "$name" = "null" ]] && name="my-foundation-mod"
              local target="$GAME_MODS_DIR/$name"
              echo "Installing mod to: $target"
              mkdir -p "$target"
              rsync -av --delete \
                --exclude='.git/' \
                --exclude='.direnv/' \
                --exclude='flake.lock' \
                --exclude='flake.nix' \
                --exclude='result' \
                --exclude='docs/' \
                ./ "$target"
              echo "Done."
            }

            watch-mod() {
              local name
              name=$(jq -r '.Name' mod.json 2>/dev/null | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
              [[ -z "$name" || "$name" = "null" ]] && name="my-foundation-mod"
              local target="$GAME_MODS_DIR/$name"
              echo "Watching for changes. Reload in-game with Ctrl+Shift+R"
              ${inotifyBin} -m -r -e modify,create,delete,move \
                --exclude '(.git|.direnv|result|docs|flake\.)' \
                --format '%w%f' . | while read -r file; do
                local rel
                rel=$(realpath --relative-to=. "$file" 2>/dev/null)
                local target_file="$target/$rel"
                mkdir -p "$(dirname "$target_file")"
                if [ -f "$file" ]; then
                  cp "$file" "$target_file"
                  echo "[$(date +%H:%M:%S)] Synced: $rel"
                fi
              done
            }

            lint-mod() {
              echo "Running Lua syntax check..."
              find . -name '*.lua' -not -path './.direnv/*' -not -path './docs/*' \
                -exec ${luaBin} -p {} \;
              echo "Lint passed."
            }

            echo "  Commands:"
            echo "    install-mod   Copy mod to game's mods folder"
            echo "    watch-mod     Watch files and auto-sync to game"
            echo "    lint-mod      Check Lua syntax"
            echo ""
          '';
        };
      };
    };
}
