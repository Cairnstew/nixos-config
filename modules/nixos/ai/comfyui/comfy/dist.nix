# Repo-local ComfyUI distribution definition — vendored from the
# `stable-diffusion-webui-nix` input's `source/comfy/default.nix`, pinned to
# **v0.29.2** (the input's `main` still pins v0.25.1 which has NO native Krea 2
# support). Kept in this repo so the root flake input is not forked.
#
# Why a vendored copy at all:
# - The input builds `stable-diffusion-webui.comfy` from its own pinned source,
#   so bumping the input would not help unless upstream bumps comfy (it hasn't).
# - The flexseal lock (`install-instructions-cuda.json` next to this file) is a
#   hash-pinned environment generated FROM the pinned ComfyUI requirements.txt
#   by `comfy-dist.nix`'s `update-helper`. We regenerate it for the pinned
#   version (see the README's "Upgrading ComfyUI" section), because a source
#   swap without re-locking would leave the python env at the old version's
#   requirements (e.g. missing `comfy-angle`, stale `comfyui-frontend-package`).
#
# `webuiPkgs` produced here is consumed by the input's OWN requirements
# machinery (`${stable-diffusion-webui-nix}/requirements`), exactly like the
# input's `overlay.nix` `constructPackage` does, so the python env, CUDA
# fixups, and runtime wrapper are all built by upstream-tested code.
{ pkgs
, mkWebuiDistrib
}:
let
  sourceDerivation = pkgs.stdenv.mkDerivation {
    name = "ComfyUI";

    src = pkgs.fetchFromGitHub {
      owner = "comfy-org";
      repo = "ComfyUI";
      rev = "v0.29.2";
      hash = "sha256-FB3sTzpMTrnNVvXFLyMqi7gUP+R8LBn3JuSF+gqj9AE=";
    };

    patches = [ ];

    installPhase = ''
      cp -r . "$out"
    '';
  };

  createPackage = import ./package.nix;
in
{
  cuda = mkWebuiDistrib {
    source = sourceDerivation;
    python = pkgs.python313;

    additionalRequirements = [
      # Required for most video extensions, common enough to be included
      # here
      { name = "diffusers"; op = ">="; spec = "0.32.0"; }
      { name = "accelerate"; op = ">="; spec = "1.2.1"; }
      { name = "transformers"; op = ">="; spec = "4.49.1"; }
      { name = "jax"; op = ">="; spec = "0.4.28"; }
      { name = "sentencepiece"; op = ">="; spec = "0.2.0"; }
      { name = "huggingface_hub"; }
      { name = "einops"; }
      { name = "peft"; }
      { name = "opencv-python"; }
      { name = "imageio-ffmpeg"; }
      { name = "bitsandbytes"; }
      { name = "matplotlib"; }
      { name = "mss"; }
      { name = "color-matcher"; }
      { name = "ftfy"; }
      { name = "protobuf"; }
      { name = "sageattention"; }
      { name = "timm"; }
    ];

    installInstructions = ./install-instructions-cuda.json;

    inherit createPackage;
  };
}
