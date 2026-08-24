# =============================================================================
# playlist-builder.nix — shared "hashify" playlist builder
# =============================================================================
# Turns a playlist directory (songs.toml declaration + checksums.json pin file)
# into one store derivation containing every song as a fixed-output derivation,
# exactly like packwiz modpacks: metadata lives in git, the committed
# checksums.json pins each song's URL + sha256, and Nix builds/verifies the
# bytes at build time.
#
# Consumed by:
#   - modules/flake-parts/music.nix  → packages."music-playlist-<name>" /
#                                     apps."music-install-<name>"
#   - modules/nixos/music/config.nix → systemd oneshot install service per
#                                     enabled playlist
#
# Playlist directory layout (mirrors a modpack dir):
#   <name>/
#   ├── songs.toml        # declaration: name, source, [[songs]] (key, url, format?)
#   └── checksums.json    # generated + committed: { "<key>": { url, sha256 } }
#
# song sources:
#   source = "direct"  → byte-stable URL (archive.org, jamendo, …). Built with
#                        pkgs.fetchurl: fully deterministic, no runtime network.
#   source = "yt-dlp"  → best-effort (YouTube, …). Built as a fixed-output
#                        derivation that runs yt-dlp INSIDE the build (FOD
#                        builds are allowed network); the committed sha256 pins
#                        the exact bytes. If the source re-encodes/changes, the
#                        build fails with a hash mismatch — regenerate with
#                        `nix run .#music-checksums-<name>` first.
# =============================================================================

{ pkgs
, lib
, playlistDir
, name
}:

let
  inherit (lib) concatMapStringsSep;
  inherit (pkgs) runCommand fetchurl writeText;

  songsToml = builtins.fromTOML (builtins.readFile "${playlistDir}/songs.toml");
  checksums = builtins.fromJSON (builtins.readFile "${playlistDir}/checksums.json");
  source = songsToml.source or "direct";

  # Filename suffix: from the URL's file extension (direct) or the yt-dlp
  # format selector (yt-dlp, e.g. "ba[ext=m4a]" → m4a).
  extFromUrl = url:
    let
      path = builtins.baseNameOf (builtins.head (lib.splitString "?" url));
      parsed = lib.splitString "." path;
    in
    if builtins.length parsed > 1 then lib.last parsed else "audio";
  extFromFormat = fmt:
    let m = builtins.match ".*ext=([a-zA-Z0-9]+).*" fmt;
    in if m == null then "m4a" else builtins.head m;
  songExt = song:
    if source == "yt-dlp" then extFromFormat (song.format or "ba[ext=m4a]")
    else extFromUrl song.url;

  # Fixed-output derivation for one song.
  buildSong = song:
    let
      cs = checksums.${song.key} or (throw ''
        my.services.music: playlist ${name}: song "${song.key}" has no entry in checksums.json.
        Run `nix run .#music-checksums-${name}` (after `git add`ing the songs.toml
        change) and commit the regenerated checksums.json.
      '');
    in
    if source == "direct" then
      fetchurl
        {
          inherit (cs) url sha256;
        }
    else
      runCommand "song-${name}-${song.key}"
        {
          inherit (cs) sha256;
          outputHashMode = "flat";
          outputHashAlgo = "sha256";
          nativeBuildInputs = [ pkgs.yt-dlp ];
        } ''
        export HOME="$TMPDIR"
        yt-dlp --no-playlist --no-mtime --ignore-config --no-update \
          -f '${song.format or "ba[ext=m4a]"}' \
          --extractor-args '${song.extractorArgs or "youtube:player_client=web_embedded"}' \
          -o $out '${song.url}'
      '';

  songLinks = concatMapStringsSep "\n"
    (song:
      let
        built = buildSong song;
      in
      "ln -s '${built}' \"$out/${song.key}.${songExt song}\""
    )
    songsToml.songs;

  manifest = writeText "manifest.json" (builtins.toJSON {
    inherit name source;
    songs = map
      (s: {
        key = s.key;
        file = "${s.key}.${songExt s}";
        title = s.title or null;
        inherit (s) url;
        inherit source;
      })
      songsToml.songs;
  });
in
runCommand "music-playlist-${name}" { passthru = { inherit manifest source; }; } ''
  mkdir -p $out
  ${songLinks}
  cp ${manifest} $out/manifest.json
''
