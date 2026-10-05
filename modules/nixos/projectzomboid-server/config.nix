# modules/nixos/projectzomboid-server/config.nix
# Host-local wiring for the upstream nixos-projectzomboid-servers module.
#
# There are no `my.*` options here on purpose: the upstream module owns the whole
# option surface under `services.project-zomboid-servers.*`, and re-exporting it
# under `my.*` would mean duplicating every option and drifting out of sync on
# each `nix flake update`. What legitimately stays local is the handful of
# decisions that are about THIS config rather than about Project Zomboid: which
# disk holds the data, who may read it, and how the consoles reach the proxy.
{ config, flake, lib, ... }:

let
  cfg = config.services.project-zomboid-servers;
  me = flake.config.me;

  # Upstream deliberately knows about no reverse-proxy module — a standalone
  # flake cannot depend on someone's private option namespace. It exposes plain
  # data per web-console server instead (`webConsoleUpstreams`), and the
  # consumer maps that into whatever proxy it uses. This is that mapping.
  #
  # Inert while `web.enable` is false (the default): the list is empty, so
  # nothing is registered.
  #
  # NOTE the dynamic-key shape. `my.services.proxy.upstreams` is `attrsOf`, and
  # mkMerge on an attrsOf option merges the list's elements AS the attrset — so
  # each element must already be `{ <upstream name> = <definition>; }`.
  # Two plausible-looking alternatives both register nothing, silently:
  #   { inherit (u) port path …; name = u.name; }   # mkMerge splats port/path/
  #                                               # name as top-level keys
  #   lib.nameValuePair u.name { …; }              # yields { name = …; value = … }
  # `nix eval` shows the difference: upstreams = [ "name" "value" ] vs
  # upstreams = [ "pz-knox" ]. Upstream's README suggests the first form.
  pzUpstreams = lib.mkMerge (map
    (u: {
      ${u.name} = {
        inherit (u) port path stripPrefix displayName;
        # ttyd listens on `web.bind`, so the proxy has to target that address.
        # It must be an IP rather than an interface name.
        host = cfg.web.bind;
      };
    })
    cfg.webConsoleUpstreams);
in
{
  config = lib.mkIf cfg.enable {
    # Adopt the upstream catalogue wholesale. It is plain data (a flake output,
    # not a module), so wiring it costs no extra options and no import — and
    # packs stay versioned with the code that understands them instead of being
    # forked here. Today that is `vanilla-plus` and `survival-hard`.
    # mkDefault so a host can replace it or layer a local pack over it; to
    # cherry-pick instead, assign e.g.
    #   modpacks = { vanilla-plus = flake.inputs.project-zomboid-servers.modpacks.vanilla-plus; };
    #
    # dataDir: keep the server on the large SATA data disk instead of the NVMe
    # root. The dedicated-server download is several GB and PZ saves grow
    # without bound, so `/var` (upstream's default) would quietly fill the root
    # filesystem on this host. mkDefault so a per-host override still wins.
    services.project-zomboid-servers = {
      modpacks = lib.mkDefault flake.inputs.project-zomboid-servers.modpacks;
      dataDir = lib.mkDefault "/mnt/data/project-zomboid";
    };

    # The PZ server runs as `project-zomboid` and the launcher reads
    # pz-admin-password (servers/knox.nix → adminAccount.passwordFile) itself,
    # so the decrypted /run/agenix file has to be group-readable by it.
    #
    # The manifest cannot say so directly: agenix runs an unconditional
    # `chown owner:group` at activation, and the group only exists once
    # services.project-zomboid-servers is enabled. Declaring `project-zomboid`
    # in the manifest would therefore break `nixos-rebuild` on every host where
    # PZ is off. Root ownership works everywhere (the feature is dormant), and
    # this hands the group over the moment it matters.
    age.secrets.pz-admin-password = {
      group = lib.mkForce cfg.group;
      mode = lib.mkForce "0440";
    };

    # Upstream creates the system user and its group but never adds this repo's
    # primary user, which leaves `seanc` unable to read the data dir or attach
    # to the console sockets. Mirrors what the pre-upstream module did.
    users.groups.${cfg.group}.members = [ me.username ];

    # Per-server ttyd consoles auto-register on the Caddy dashboard, e.g.
    # https://<host>.<tailnet>.ts.net/pz/knox/. Replaces the pre-upstream
    # `web.proxyUpstream` option, which upstream cannot express.
    my.services.proxy.upstreams = pzUpstreams;
  };
}
