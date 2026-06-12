{ lib, stdenvNoCC, fetchurl, makeWrapper, jdk_headless }:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "suwayomi-server";
  version = "2.2.2100";

  src = fetchurl {
    url = "https://github.com/Suwayomi/Suwayomi-Server/releases/download/v${finalAttrs.version}/Suwayomi-Server-v${finalAttrs.version}.jar";
    hash = "sha256-PIEypDv6m5WbDI/b3PmqAb2AkEf/T7waSq4OtxMx8F4=";
  };

  nativeBuildInputs = [ makeWrapper ];

  dontUnpack = true;

  buildPhase = ''
    runHook preBuild
    makeWrapper ${jdk_headless}/bin/java $out/bin/suwayomi-server \
      --add-flags "-Dsuwayomi.tachidesk.config.server.initialOpenInBrowserEnabled=false -jar $src"
    runHook postBuild
  '';

  meta = {
    description = "Free and open source manga reader server that runs extensions built for Mihon (Tachiyomi)";
    homepage = "https://github.com/Suwayomi/Suwayomi-Server";
    license = lib.licenses.mpl20;
    platforms = jdk_headless.meta.platforms;
    sourceProvenance = [ lib.sourceTypes.binaryBytecode ];
    mainProgram = "suwayomi-server";
    maintainers = [ "seanc" ];
  };
})
