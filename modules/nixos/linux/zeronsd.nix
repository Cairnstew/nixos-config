{ flake, lib, config, pkgs, ... }:

let
  inherit (flake.config.me) zerotier_networks;
  inherit (flake.inputs) self;
  secretFile = self + /secrets/zeronsd-token.age;
in
{
  services.zerotierone.enable = true;

  # 🔍 Nix build-time debug: print what path 'self' resolves to
  # Will print during evaluation
  _module.args._trace = builtins.trace "DEBUG: zeronsd secret path resolved to: ${toString secretFile}" null;

  age.secrets."zeronsd-token" = {
    file = secretFile;
    owner = "zeronsd";
    mode = "0400";
  };

  # Dynamically configure zeronsd for each network
  services.zeronsd.servedNetworks =
    lib.genAttrs zerotier_networks (networkId: {
      settings = {
        token = config.age.secrets."zeronsd-token".path;
      };
    });

  # 🔍 Runtime debugging via systemd unit
  systemd.services.debug-zeronsd-secret = {
    description = "Debug Agenix zeronsd secret";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "debug-zeronsd-secret" ''
        echo "===== DEBUG zeronsd secret ====="
        echo "Nix secret file reference: ${toString secretFile}"
        echo "Agenix decrypted path: ${config.age.secrets."zeronsd-token".path}"
        echo "Does decrypted secret exist?"
        if [ -f ${config.age.secrets."zeronsd-token".path} ]; then
          echo "✅ Secret file exists"
          ls -l ${config.age.secrets."zeronsd-token".path}
        else
          echo "❌ Secret file missing!"
          ls -l /run/agenix.d/* || true
        fi
        echo "================================="
      '';
    };
  };
}
