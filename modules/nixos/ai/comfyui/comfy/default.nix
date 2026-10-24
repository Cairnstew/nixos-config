# Repo-local ComfyUI **package** builder — builds the ComfyUI x.xx distribution
# defined in `./dist.nix` (currently ComfyUI v0.29.2) using the
# `stable-diffusion-webui-nix` input's own requirements machinery, so the CUDA
# python env, per-package fixups and the runtime wrapper are built by
# upstream-tested code (this is exactly what the input's `overlay.nix`
# `constructPackage` does internally).
#
# The user-visible package is `config.services.comfyUi.package`, which the
# comfyui module overrides to this derivation so the whole module runs the
# newer ComfyUI without forking the flake input.
{ pkgs
, flake
, extraPythonPackages ? [ ]
}:
let
  # The stable-diffusion-webui-nix flake input (pinned in flake.lock) provides
  # the requirements machinery (`${input}/requirements`) and the source
  # scaffolding (`${input}/source/{default,comfy/default}.nix`). We reuse the
  # former; the latter (the actual distribution definition) is vendored in
  # `./dist.nix` because we need a different ComfyUI pin than the input ships.
  input = flake.inputs.stable-diffusion-webui-nix;
  inputSrc = input.outPath or (throw "my.services.comfyui: cannot resolve stable-diffusion-webui-nix input path; flake arg missing?");

  # This mirrors `mkWebuiDistrib` from `${inputSrc}/source/default.nix` — the
  # input does not export it, so we inline the same tiny helper.
  mkWebuiDistrib =
    { source
    , python
    , createPackage
    , additionalRequirements ? [ ]
    , additionalBuildRequirements ? [ ]
    , additionalBuildInputs ? [ ]
    , additionalPipArgs ? [ ]
    , installInstructions
    , requirementsFileName ? "requirements.txt"
    }@args:
    {
      type = "stable-diffusion-webui-derivation";
      inherit additionalPipArgs;
      inherit additionalRequirements;
      inherit additionalBuildRequirements;
      inherit additionalBuildInputs;
      inherit requirementsFileName;
    } // args;

  # The vendored distribution definition (currently comfy v0.29.2)
  sources = import ./dist.nix {
    inherit pkgs mkWebuiDistrib;
  };
  webuiPkgs = sources.cuda;

  # The input's requirements machinery builds a python env from the locked
  # install-instructions.json (the vendored ./install-instructions-cuda.json)
  # — same code path upstream uses for the version it ships.
  requirementsBase = pkgs.callPackage "${inputSrc}/requirements" { inherit webuiPkgs; };

  # Extra package fixups on top of the input's own (requirements/compat/
  # package-fixups.nix). The regenerated lock resolves NEWER wheel versions
  # than the input's lock, and some of those wheels need ignore-entries the
  # input's fixup list doesn't have yet:
  # - bitsandbytes 0.50.x bundles ROCm loader stubs (libbitsandbytes_rocm*.so)
  #   that auto-patchelf hard-fails on with `missing librocrand.so.1` etc. They
  #   are never dlopen'd on this CUDA machine, so ignore them like the input
  #   already ignores libhipblas/libhipblaslt.
  extraFixups = _final: prev: {
    bitsandbytes = prev.bitsandbytes.overridePythonAttrs (o: {
      autoPatchelfIgnoreMissingDeps =
        (o.autoPatchelfIgnoreMissingDeps or [ ])
        ++ [
          "librocrand.so.1"
          "librccl.so.1"
          "libamdhip64.so.5"
          "libamdhip64.so.6"
          "libhsa-runtime64.so.1"
          "libhiprtc.so.5"
          "libhiprtc.so.6"
          "librocblas.so.4"
          "librocsparse.so.4"
          "librocsolver.so.5"
          "libhipsolver.so.1"
          "libsycl.so.9"
        ];
    });
  };
  # Extend the SAME python env that ComfyUI runs with, rather than injecting a
  # second PYTHONPATH env.  `ignoreCollisions = true` keeps the locked base
  # package first on any file collision, so a node dependency can never shadow
  # ComfyUI's pinned torch/numpy/etc.  New packages are appended by the
  # `python.withPackages` wrapper.
  requirements = requirementsBase // {
    requirementPkgs = requirementsBase.requirementPkgs.overrideScope (final: prev:
      (extraFixups final prev) // {
        webui-python-env = prev.webui-python-env.override {
          extraLibs = prev.allRequirements ++ extraPythonPackages;
          ignoreCollisions = true;
        };
      });
  };

  # The runtime wrapper (vendored from the input's source/comfy/package.nix).
  runner = pkgs.callPackage webuiPkgs.createPackage { inherit webuiPkgs requirements; };
in
runner // {
  inherit (requirements) update-helper;
  inherit requirements;
  version = "0.29.2";
}
