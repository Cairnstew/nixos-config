# modules/nixos/projectzomboid-server/options.nix
#
# Intentionally empty.
#
# This module declares no `my.*` options: the entire option surface belongs to
# the upstream module imported in default.nix, under the
# `services.project-zomboid-servers.*` namespace. See the upstream
# docs/options.md (completeness-checked in its own CI) for every option — do not
# mirror them here; a copy would be a second source of truth that silently rots
# on `nix flake update`.
#
# The file exists because modules/AGENT.md §5.2 lists it in the canonical module
# layout. It is NOT imported by default.nix, because there is nothing in it to
# import — hence no function arguments and no lint noise.
{ }
