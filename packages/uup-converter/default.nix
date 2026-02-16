{ lib
, stdenv
, fetchgit
, makeWrapper
, bash
, aria2
, cabextract
, wimlib
, chntpw
, cdrkit
, p7zip
}:
stdenv.mkDerivation rec {
  pname = "uup-converter";
  version = "latest";
  
  src = fetchgit {
    url = "https://git.uupdump.net/uup-dump/converter.git";
    rev = "HEAD";
    sha256 = "sha256-1B0zxoN4FnQExpzy8mV+/ih70ze1jgtVjCyOZ6Kn4Wc=";
  };
  
  nativeBuildInputs = [
    makeWrapper
    bash
    aria2
    cabextract
    wimlib
    chntpw
    cdrkit
    p7zip
  ];
  
  dontBuild = true;
  
  postPatch = ''
    # Replace 'which' with 'command -v' (bash builtin, more reliable)
    sed -i 's|which \([^ ]*\) &>/dev/null 2>&1|command -v \1 \&>/dev/null|g' convert.sh
    sed -i 's|which \([^ ]*\) &>/dev/null|command -v \1 \&>/dev/null|g' convert.sh
  '';
  
  installPhase = ''
    mkdir -p $out/bin
    install -m755 convert.sh $out/bin/uup-converter
    wrapProgram $out/bin/uup-converter \
      --prefix PATH : ${lib.makeBinPath [
        aria2
        cabextract
        wimlib
        chntpw
        cdrkit
        p7zip
        bash
      ]}
  '';
  
  meta = with lib; {
    description = "UUP Dump Converter – build Windows ISOs from UUP files";
    homepage = "https://git.uupdump.net/uup-dump/converter";
    license = licenses.gpl3Only;
    platforms = platforms.linux;
    maintainers = [ ];
  };
}