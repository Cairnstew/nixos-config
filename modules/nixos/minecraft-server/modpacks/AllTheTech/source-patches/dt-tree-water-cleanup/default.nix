# dt-tree-water-cleanup — build our own NeoForge mod from this repo's source.
#
# This is not a patch to an upstream mod; it is a standalone compat mod that
# fixes the Dynamic-Trees-in-Streams-Reflowing-lakes issue at the worldgen level
# (see extra-mods.nix). Reuses buildModSource so both the client (packwiz.nix)
# and the server (minecraft-server/config.nix) get identical jars; the FOD
# allows network so Gradle + the NeoForge toolchain download inside the build.
#
# outputHash: fixed-output sha256 of the built jar. Compute once with
#   nix build --impure .#nixosConfigurations.server.config.system.build.toplevel... 
# (or directly the patch derivation) and paste the "got:" hash from the
# mismatch error. Current value: TODO replaced after first build.
{ buildModSource
, curl
, unzip
, cacert
}:
buildModSource {
  name = "dt-tree-water-cleanup-1.0.0.jar";
  src = ./src;
  patches = [ ];
  extraNativeBuildInputs = [ curl unzip ];
  buildCmd = ''
    set -e
    # The Nix sandbox sets SSL_CERT_FILE=/no-cert-file.crt; give curl a real
    # bundle so it can fetch the Gradle distribution.
    export SSL_CERT_FILE=${cacert}/etc/ssl/certs/ca-bundle.crt
    export GRADLE_USER_HOME="$HOME/.gradle"
    # MDG 2.0.x needs Gradle 8.7+; nixpkgs' gradle version is not guaranteed
    # compatible (Loom/MDG both reject newer/older majors), so fetch the exact
    # pinned distribution inside the FOD (network is allowed here).
    curl -sSL -o "$HOME/gradle.zip" https://services.gradle.org/distributions/gradle-8.8-bin.zip
    unzip -q "$HOME/gradle.zip" -d "$HOME"
    "$HOME/gradle-8.8/bin/gradle" --no-daemon --stacktrace build
    jar=$(ls build/libs/*.jar 2>/dev/null | grep -v -E 'sources|dev|plain|api' | head -1)
    if [ -z "$jar" ]; then
      echo "dt-tree-water-cleanup: no playable jar found under build/libs/" >&2
      exit 1
    fi
    cp "$jar" "$out"
  '';
  outputHash = "sha256-R3NbL3/eFn6FuPOjljCxPGDHI1Yu5/YzpXc/Lvs3eLk=";
}
