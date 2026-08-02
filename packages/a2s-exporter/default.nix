{ lib, buildGoModule, fetchFromGitHub }:

buildGoModule rec {
  pname = "a2s-exporter";
  version = "0.4.0";

  src = fetchFromGitHub {
    owner = "armsnyder";
    repo = "a2s-exporter";
    rev = "v${version}";
    hash = "sha256-ySYk4p23waALOoR53npI/SUPgEThYUCM4YHL+E4xDJM=";
  };

  vendorHash = "sha256-jdI78Ka50vaghJst4M1orcP9XyV+v/FqrqCpqBuRZpg=";

  meta = {
    description = "Prometheus exporter for Steam game servers using the A2S query protocol";
    longDescription = ''
      Generic Prometheus exporter for any Steam game server that speaks the
      UDP-based A2S query protocol (CS2, TF2, Rust, Valheim, The Forest, ...).

      Usage:
        a2s-exporter --address <server>:<queryport> --port <metrics-port>
    '';
    homepage = "https://github.com/armsnyder/a2s-exporter";
    license = lib.licenses.mit;
    mainProgram = "a2s-exporter";
    maintainers = [ ];
  };
}
