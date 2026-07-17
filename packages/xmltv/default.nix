{ lib, stdenv, fetchFromGitHub, makeWrapper, perl, perlPackages }:

let
  perlEnv = perl.withPackages (pp: with pp; [
    DateManip
    FileSlurp
    JSON
    LWP
    LWPProtocolHttps
    URI
    TermReadKey
    XMLParser
    XMLTreePP
    XMLTwig
    XMLWriter
    DateTime
    FilePath
    HTTPMessage
  ]);
in
stdenv.mkDerivation rec {
  pname = "xmltv";
  version = "1.4.0";

  src = fetchFromGitHub {
    owner = "XMLTV";
    repo = "xmltv";
    rev = "v${version}";
    hash = "sha256-edfg18E8BSBZy5OVL0T5F/SmNiSlbHZeQH/a9XCSDnE=";
  };

  nativeBuildInputs = [ makeWrapper ];
  buildInputs = [ perlEnv ];

  buildPhase = ''
    runHook preBuild
    perl lib/XMLTV.pm.PL lib/XMLTV.pm
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/lib/XMLTV $out/lib/HTTP/Cache

    # Install XMLTV.pm (generated) - Perl looks for XMLTV.pm directly in @INC
    cp lib/XMLTV.pm $out/lib/XMLTV.pm

    # Install all XMLTV library modules (these live in XMLTV/ namespace at install)
    for f in lib/*.pm lib/*.pm.in; do
      base=$(basename "$f" .in)
      name=$(basename "$base" .pm)
      [ "$name" = "XMLTV" ] && continue
      [ "$name" = "Supplement" ] && continue
      [ "$f" = "lib/*.pm.in" ] && continue
      cp "$f" "$out/lib/XMLTV/$name.pm" 2>/dev/null || true
    done

    # Install sub-directories
    for dir in lib/*/; do
      [ -d "$dir" ] || continue
      target="$out/lib/XMLTV/$(basename "$dir")"
      mkdir -p "$target"
      cp "$dir"*.pm "$dir"*.pl "$target"/ 2>/dev/null || true
    done

    # Install grab library modules
    cp grab/Memoize.pm $out/lib/XMLTV/
    cp grab/Grab_XML.pm $out/lib/XMLTV/
    cp grab/DST.pm $out/lib/XMLTV/
    cp grab/Config_file.pm $out/lib/XMLTV/
    cp grab/Get_nice.pm $out/lib/XMLTV/
    cp grab/Mode.pm $out/lib/XMLTV/

    # Provide stub for HTTP::Cache::Transparent (not in nixpkgs)
    cat > $out/lib/HTTP/Cache/Transparent.pm << 'STUB'
package HTTP::Cache::Transparent;
use strict;
use warnings;
our $VERSION = '1.4';
sub init {
    my ($class, %args) = @_;
    # Stub - no-op implementation
}
1;
STUB

    # Install tv_grab_uk_freeview
    cp grab/uk_freeview/tv_grab_uk_freeview $out/bin/

    # Install core filter/tool scripts
    for f in filter/tv_* tools/tv_*; do
      [ -f "$f" ] || continue
      case "$f" in *.PL|*.in) continue;; esac
      cp "$f" "$out/bin/"
    done

    chmod +x $out/bin/*

    for f in $out/bin/*; do
      wrapProgram "$f" --prefix PERL5LIB : "$out/lib"
    done

    runHook postInstall
  '';

  meta = {
    description = "TV listings grabber for UK Freeview (tv_grab_uk_freeview)";
    homepage = "https://github.com/XMLTV/xmltv";
    license = lib.licenses.gpl2Only;
    maintainers = with lib.maintainers; [ ];
    platforms = lib.platforms.linux;
  };
}
