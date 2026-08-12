{ config, lib, pkgs, ... }:
let
  cfg = config.my.services.risuai;
  backendBin =
    if cfg.backend == "docker"
    then "${pkgs.docker}/bin/docker"
    else "${pkgs.podman}/bin/podman";

  # Patches the root (settings) record of RisuAI's database.bin save file.
  # RisuAI has no env-var/config-file mechanism for UI settings, so the
  # only server-side way to seed defaults is to rewrite this record.
  # Format: "RISUSAVE\x00" magic, then [u16 type][u8 pathlen][path][u32 clen][content].
  patchSettingsScript = pkgs.writeText "risuai-patch-settings.py" ''
    import json, os, struct, sys

    dataDir = sys.argv[1]
    desired = json.loads(sys.argv[2])

    def hexname(name):
        try:
            return bytes.fromhex(name).decode('utf-8')
        except Exception:
            return None

    def find_db():
        for f in os.listdir(dataDir):
            p = os.path.join(dataDir, f)
            if os.path.isfile(p) and hexname(f) == 'database/database.bin':
                return p
        return None

    dbpath = find_db()
    if not dbpath:
        print('RISUSAVE: database.bin not found under', dataDir)
        sys.exit(0)

    data = open(dbpath, 'rb').read()
    magic = b'RISUSAVE\x00'
    if not data.startswith(magic):
        print('RISUSAVE: bad magic in', dbpath)
        sys.exit(0)
    pos = len(magic)
    records = []
    while pos < len(data):
        t = struct.unpack('<H', data[pos:pos+2])[0]
        plen = data[pos+2]
        path = data[pos+3:pos+3+plen].decode('utf-8', 'replace')
        pos += 3 + plen
        clen = struct.unpack('<I', data[pos:pos+4])[0]
        content = data[pos+4:pos+4+clen]
        pos += 4 + clen
        records.append((t, path, content))

    changed = False
    for i, (t, path, content) in enumerate(records):
        if t == 1:
            obj = json.loads(content)
            for k, v in desired.items():
                if obj.get(k) != v:
                    obj[k] = v
                    changed = True
            if changed:
                records[i] = (t, path, json.dumps(obj, separators=(',', ':'), ensure_ascii=False).encode('utf-8'))

    if not changed:
        print('RISUSAVE: settings already applied')
        sys.exit(0)

    out = bytearray(magic)
    for t, path, content in records:
        pb = path.encode('utf-8')
        out += struct.pack('<H', t)
        out.append(len(pb))
        out += pb
        out += struct.pack('<I', len(content))
        out += content

    pos = len(magic)
    n = 0
    while pos < len(out):
        struct.unpack('<H', out[pos:pos+2])
        plen = out[pos+2]
        pos += 3 + plen
        clen = struct.unpack('<I', out[pos:pos+4])[0]
        pos += 4 + clen
        n += 1
    assert pos == len(out), 'reparse mismatch'

    tmp = dbpath + '.risuai-patch.tmp'
    open(tmp, 'wb').write(bytes(out))
    os.replace(tmp, dbpath)
    print('RISUSAVE: patched %d setting(s) in %s' % (len(desired), dbpath))
  '';
in
{
  config = lib.mkIf cfg.enable {
    systemd.services."risuai-apply-settings" = lib.mkIf (cfg.settings != { }) {
      description = "Enforce RisuAI default user settings in the save database";
      before = [ "${cfg.backend}-risuai.service" ];
      requiredBy = [ "${cfg.backend}-risuai.service" ];
      serviceConfig = {
        Type = "oneshot";
        User = "root";
      };
      script = ''
        ${pkgs.python3}/bin/python3 ${patchSettingsScript} \
          ${lib.escapeShellArg cfg.dataDir} \
          ${lib.escapeShellArg (builtins.toJSON cfg.settings)}
      '';
    };

    systemd.services."${cfg.backend}-risuai" = {
      serviceConfig = {
        Restart = lib.mkOverride 90 cfg.restart.policy;
        RestartMaxDelaySec = lib.mkOverride 90 cfg.restart.maxDelaySec;
        RestartSec = lib.mkOverride 90 cfg.restart.delaySec;
        RestartSteps = lib.mkOverride 90 cfg.restart.steps;

        ExecStartPre = lib.mkOverride 90
          "${pkgs.writeShellScript "risuai-create-network" ''
            if ! ${backendBin} network inspect ${lib.escapeShellArg cfg.network.name} > /dev/null 2>&1; then
              echo "Creating network ${cfg.network.name}..."
              ${backendBin} network create ${lib.escapeShellArg cfg.network.name}
            fi
          ''}";

        ExecStartPost = lib.mkOverride 90
          "${pkgs.writeShellScript "risuai-container-probe" ''
            echo "[risuai probe] waiting for web UI..."
            for i in $(${pkgs.coreutils}/bin/seq 1 60); do
              if ${pkgs.curl}/bin/curl -sf http://127.0.0.1:${toString cfg.port}/ > /dev/null 2>&1; then
                echo "[risuai probe] UI reachable (attempt $i)"
                exit 0
              fi
              sleep 1
            done
            echo "[risuai probe] FAIL: UI not reachable after 60s" >&2
            exit 1
          ''}";
      };
    };
  };
}
