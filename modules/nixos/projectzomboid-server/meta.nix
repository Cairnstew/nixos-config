{
  name = "projectzomboid-server";
  description = "Thin wrapper wiring the upstream nixos-projectzomboid-servers flake module (services.project-zomboid-servers.*) into this config: large-disk dataDir, primary-user group membership, reverse-proxy upstreams, and this repo's server catalog";
  category = "gaming";
  tags = [ "gaming" "project-zomboid" "steam" "steamcmd" "server" "modpack" "workshop" "ttyd" ];
  provides = [ "services.project-zomboid-servers" ];
  expects = [ "my.services.proxy" ];
  complexity = "low";
  tested = true;
  homepage = "https://pzwiki.net/wiki/Dedicated_server";
  maintainer = "seanc";

  # The whole implementation is upstream. `mode = wrapped` because this repo
  # never had a vendored copy — it consumes the flake input directly and keeps
  # only host-local wiring here. Implementation changes (module behaviour,
  # the modpack catalogue, the CLI apps, upstream docs/.opencode) belong in the
  # space below; only dataDir / secret group / proxy / tests / servers stay
  # local. See modules/AGENT.md §4.2 and README.md "Implementation changes
  # belong upstream".
  #
  # TO MAKE AN UPSTREAM CHANGE: load the `opencode-ensemble` skill, then spawn
  # into the space rather than editing this repo —
  #
  #   team_spawn name="pz-fix" space="project-zomboid-servers" worktree=false \
  #              prompt="<the concrete upstream change>"
  #
  # `worktree=false` is mandatory (spaces and worktrees are mutually exclusive).
  # The space clones /home/seanc/Projects/nixos-projectzomboid-servers, which
  # is the repo `flakeInput = "project-zomboid-servers"` points at; after it
  # pushes, re-pin with
  #   nix flake update project-zomboid-servers \
  #     --option access-tokens "github.com=$GITHUB_TOKEN"   # private input
  # and re-run upstream's own suite before rebuilding this host.
  #
  # This module declares NO options of its own (options.nix is intentionally
  # empty), so anything declared in upstream's modules/options.nix is upstream's
  # to change — there is no ambiguous middle ground.
  upstream = {
    repo = "github:Cairnstew/nixos-projectzomboid-servers";
    mode = "wrapped";
    space = "project-zomboid-servers";
    flakeInput = "project-zomboid-servers";
  };
}
