# remote.nix — pure helpers for building Zed `ssh_connections` entries.
#
# Imported by both `config.nix` (to emit settings) and `tests.nix` (to assert
# against the same code the settings come from). Keeping this logic here — free
# of `config`/`pkgs` — is deliberate: the previous inline version could only be
# exercised by enabling the option on a real host, which is exactly how a
# generator/converter key mismatch shipped broken (see tests.nix).
#
# Zed's remote-development schema is snake_case in JSON
# (https://zed.dev/docs/remote-development):
#
#   { "host": …, "username": …, "port": …, "nickname": …, "args": [ … ],
#     "upload_binary_over_ssh": true,
#     "projects": [ { "paths": [ … ] } ],
#     "port_forwards": [ { "local_port": …, "remote_port": …,
#                          "local_host": …, "remote_host": … } ] }
#
# Every function here takes the module's camelCase *option* shape and returns
# Zed's JSON shape. Nix option submodules always materialise every declared
# option (with its default), so the option shape is total — that invariant is
# what makes the single-converter design safe.
{ lib }:

let
  inherit (lib) optionalAttrs;
in
rec {
  # ── Single conversion point: option shape → Zed JSON ───────────────────────
  #
  # Exactly one function owns the camelCase → snake_case mapping. The tailnet
  # auto-generator and the explicit `sshConnections` list both funnel through
  # here, so the two can never drift apart again.
  mkConnection =
    conn:
    let
      portForwards = map mkPortForward conn.portForwards;
    in
    {
      host = conn.host;
    }
    // optionalAttrs (conn.username != null) { username = conn.username; }
    // optionalAttrs (conn.port != null) { port = conn.port; }
    // optionalAttrs (conn.nickname != null) { nickname = conn.nickname; }
    // optionalAttrs (conn.args != [ ]) { args = conn.args; }
    // optionalAttrs conn.uploadBinaryOverSsh { upload_binary_over_ssh = true; }
    // optionalAttrs (conn.projects != [ ]) {
      projects = map (p: { paths = p.paths; }) conn.projects;
    }
    // optionalAttrs (portForwards != [ ]) { port_forwards = portForwards; };

  # Reads are defensive (`or null`) so a partial port-forward attrset is
  # usable; Nix option submodules materialise every field, but this file is
  # also driven directly by the fixture tests.
  mkPortForward =
    pf:
    let
      localHost = pf.localHost or null;
      remoteHost = pf.remoteHost or null;
    in
    {
      local_port = pf.localPort;
      remote_port = pf.remotePort;
    }
    // optionalAttrs (localHost != null) { local_host = localHost; }
    // optionalAttrs (remoteHost != null) { remote_host = remoteHost; };

  # Identity of a connection for dedupe. user@host:port is the right key because
  # it is how Zed matches a CLI `zed ssh://user@host:port/…` to an entry, so two
  # entries sharing it are the same connection and only the first should render.
  connectionKey = conn: "${toString conn.username}@${conn.host}:${toString conn.port}";

  # ── Tailnet host resolution ────────────────────────────────────────────────

  # Which `flake.config.tailnet` field Zed should dial. `magicDnsName` is the
  # default because it is the name Tailscale's own SSH config generator writes
  # into ~/.ssh/config.d/tailscale (`Host <short>` + `Host <fqdn>`), so Zed's
  # spawned `ssh` resolves it without extra args. `ip` is the escape hatch for
  # hosts without working MagicDNS.
  resolveHostAddress =
    { tailnetHost
    , hostField
    ,
    }:
    if hostField == "ip" then
      tailnetHost.ip
    else if hostField == "magicDnsName" then
      (
        # Strip the trailing dot Tailscale reports; `ssh` treats them alike but
        # the stripped form matches the generated config.d/tailscale block.
        if tailnetHost.magicDnsName != null && tailnetHost.magicDnsName != "" then
          lib.removeSuffix "." tailnetHost.magicDnsName
        else
          tailnetHost.hostname
      )
    else
      tailnetHost.hostname;

  # Build one auto-generated connection from a `flake.config.tailnet` entry,
  # applying any per-host override from `tailnetConnections.hosts`.
  #
  # The result is in the module's *option* shape (camelCase, every field
  # present) — never Zed's JSON shape. Feeding JSON-shaped attrsets to
  # `mkConnection` is the bug this indirection exists to prevent.
  mkTailnetConnection =
    { name
    , tailnetHost
    , override
    , defaultUsername
    , defaultProjects
    , defaultHostField
    , defaultUploadBinaryOverSsh
    , defaultArgs
    ,
    }:
    # Read override fields defensively (`or null` / `or [ ]`) so a partial
    # override attrset is usable. Nix option submodules materialise every field,
    # but this file is also driven directly by the fixture tests.
    let
      oHost = override.host or null;
      oUsername = override.username or null;
      oPort = override.port or null;
      oNickname = override.nickname or null;
      oHostField = override.hostField or null;
      oArgs = override.args or [ ];
      oUpload = override.uploadBinaryOverSsh or null;
      oProjects = override.projects or [ ];
      oPortForwards = override.portForwards or [ ];
    in
    {
      # An override may pin an explicit host (e.g. a jump alias); otherwise
      # derive it from the tailnet entry via `hostField`.
      host =
        if oHost != null then
          oHost
        else
          resolveHostAddress {
            inherit tailnetHost;
            hostField = if oHostField != null then oHostField else defaultHostField;
          };

      username = if oUsername != null then oUsername else defaultUsername;
      port = oPort;

      # Nickname is the friendly label in Zed's Remote Projects dialog. Default
      # to the tailnet's logical key so `desktop-dlstflt` reads better than its
      # MagicDNS FQDN.
      nickname = if oNickname != null then oNickname else name;

      args = if oArgs != [ ] then oArgs else defaultArgs;

      uploadBinaryOverSsh =
        if oUpload != null then oUpload else defaultUploadBinaryOverSsh;

      # An override's own project list replaces the tailnet-wide default, so a
      # host can narrow (or widen) what Zed opens without global churn.
      projects =
        if oProjects != [ ] then
          oProjects
        else if defaultProjects != [ ] then
          [{ paths = defaultProjects; }]
        else
          [ ];

      portForwards = oPortForwards;
    };

  # Resolve which tailnet hosts become Zed connections:
  #   * `include` (when non-empty) is a whitelist, otherwise every host qualifies
  #   * `exclude` always wins over `include`
  #   * a per-host override with `enable = false` drops the host
  selectedTailnetNames =
    { tailnetNames
    , include
    , exclude
    , overrides
    ,
    }:
    lib.filter
      (
        name:
        !(lib.elem name exclude)
        && ((include == [ ]) || lib.elem name include)
        && (overrides.${name}.enable or true)
      )
      tailnetNames;

  # ── Assembly ───────────────────────────────────────────────────────────────

  # Merge auto-generated and explicit connections, dropping duplicates by
  # `connectionKey`. Explicit `sshConnections` are seeded first and win, so a
  # hand-written entry for a tailnet host replaces the generated one instead of
  # appearing next to it in the Remote Projects dialog.
  mergeConnections =
    { autoConnections
    , explicitConnections
    ,
    }:
    lib.foldl'
      (
        acc: c:
        if lib.elem (connectionKey c) (map connectionKey acc) then
          acc
        else
          acc ++ [ c ]
      )
      explicitConnections
      autoConnections;

  # Build every connection Zed should know about, in option shape.
  buildConnections =
    { tailnet
    , username
    , tailnetConnections
    , sshConnections
    ,
    }:
    let
      tn = tailnetConnections;
      overrides = tn.hosts;

      autoConnections =
        if !tn.enable then
          [ ]
        else
          map
            (
              name: mkTailnetConnection {
                inherit name;
                tailnetHost = tailnet.${name};
                override = overrides.${name} or { };
                defaultUsername = username;
                defaultProjects = tn.defaultProjects;
                defaultHostField = tn.hostField;
                defaultUploadBinaryOverSsh = tn.uploadBinaryOverSsh;
                defaultArgs = tn.args;
              }
            )
            (selectedTailnetNames {
              tailnetNames = lib.attrNames tailnet;
              inherit overrides;
              include = tn.include;
              exclude = tn.exclude;
            });
    in
    mergeConnections {
      inherit autoConnections;
      explicitConnections = sshConnections;
    };
}
