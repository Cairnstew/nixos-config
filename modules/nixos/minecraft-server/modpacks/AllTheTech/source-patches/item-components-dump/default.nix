# item-components-dump — temporary diagnostic mod that dumps each registered
# item's default DataComponentMap to item-components-dump.json, then exits the JVM.
#
# NOT a permanent pack mod — built and run once during item-components-regenerate,
# the resulting jar is discarded after use.
#
# outputHash: compute with nix-build --no-out-link and paste the "got:" hash
# from the mismatch error.
{ buildModSource
, curl
, unzip
, cacert
}:
buildModSource {
  name = "item-components-dump-1.0.0.jar";
  src = ./src;
  patches = [ ];
  extraNativeBuildInputs = [ curl unzip ];
  buildCmd = ''
    set -e
    # Nix sandbox sets SSL_CERT_FILE=/no-cert-file.crt; give curl a real bundle.
    export SSL_CERT_FILE=${cacert}/etc/ssl/certs/ca-bundle.crt
    export GRADLE_USER_HOME="$HOME/.gradle"
    # MDG 2.0.x needs Gradle 8.7+; fetch the exact pinned version inside the FOD.
    curl -sSL -o "$HOME/gradle.zip" https://services.gradle.org/distributions/gradle-8.8-bin.zip
    unzip -q "$HOME/gradle.zip" -d "$HOME"
    "$HOME/gradle-8.8/bin/gradle" --no-daemon --stacktrace build
    jar=$(ls build/libs/*.jar 2>/dev/null | grep -v -E 'sources|dev|plain|api' | head -1)
    if [ -z "$jar" ]; then
      echo "item-components-dump: no playable jar found under build/libs/" >&2
      exit 1
    fi
    cp "$jar" "$out"
  '';
  outputHash = "sha256-zrwW/j+MKanllF00XUqRX3NUvQ+LJRz4gkJEcoKjwn0=";
}
