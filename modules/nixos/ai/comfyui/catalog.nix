# Curated catalog of popular, pinned ComfyUI custom nodes.
#
# Each entry is a pure, locked fetch: `url` + `rev` + `sha256` (from
# `nix-prefetch-git --url <url> --fetch-submodules`) so enabling a catalog node
# works with a plain `nixos-rebuild switch` / `nix run .#activate` (no
# --impure). `fetchSubmodules = true` matches the prefetch.
#
# Enable catalog nodes with `my.services.comfyui.presets = [ "name" ... ]` or
# override/extend with `customNodes` (an explicit `customNodes` entry with the
# same attr name wins). To bump a pin: re-run
#   nix-prefetch-git --url <url> --fetch-submodules
# and update rev + sha256 (+ the "pinned" comment).
#
# IMPORTANT runtime note: these are the SOURCE checkouts. Some packs (Impact,
# WAS, ControlNet-Aux, WD14, Florence2, LayerStyle) also pip-install python
# deps / download models on first use — with `enableManager` the runtime
# installs go to `<dataDir>/python-site-packages` (writable PIP_TARGET) and
# model downloads land in `<dataDir>`, both outside the store.
{
  # ── Workflow / QoL essentials ────────────────────────────────────────────
  ComfyUI_Comfyroll_CustomNodes = {
    url = "https://github.com/Suzie1/ComfyUI_Comfyroll_CustomNodes";
    rev = "d78b780ae43fcf8c6b7c6505e6ffb4584281ceca";
    sha256 = "1xy8alaz7w79pnrk6r30b0q22fjk7v6cz081yhh23hasv0kl7a7s";
    description = "Comfyroll Studio — SDXL/SD1.5 helper nodes (text, LoRA stack, aspect ratio, ControlNet utils)";
  };
  ComfyUI-Custom-Scripts = {
    url = "https://github.com/pythongosssss/ComfyUI-Custom-Scripts";
    rev = "609f3afaa74b2f88ef9ce8d939626065e3247469";
    sha256 = "0r0l31waz2jlfrm0zpj562f4dhrgkwcb0fxx4nkw9c3zp55i6s6q";
    description = "pythongosssss — UI QoL: Show Text, autocomplete, image feed, JS hooks, node mapping";
  };
  ComfyUI_essentials = {
    url = "https://github.com/cubiq/ComfyUI_essentials";
    rev = "9d9f4bedfc9f0321c19faf71855e228c93bd0dc9";
    sha256 = "1xdd1fvid80s1pc9ai05anqrnmk75rc0rf31jcdzia2qarjj8k62";
    description = "cubiq essentials — portable tiny utility nodes (image ops, masks, latent, math)";
  };
  was-node-suite-comfyui = {
    url = "https://github.com/WASasquatch/was-node-suite-comfyui";
    rev = "ea935d1044ae5a26efa54ebeb18fe9020af49a45";
    sha256 = "15qgg6ahbm9v08mnk72fsjyzccmsiyys8kniygxid4hc2d8si9py";
    description = "WAS Node Suite — 210+ nodes: text, image, video, process, ModelMerge, masking";
  };
  rgthree-comfy = {
    url = "https://github.com/rgthree/rgthree-comfy";
    rev = "2c5342a8cb0eaecaabf61435a5f37dd594c510ba";
    sha256 = "1rrmqmams3bvibnq8m6aqmjfip8mrnxgh279n0grqnwmxriqlz37";
    description = "rgthree — workflow UX: Reroute, Context/Bypass groups, Collect, multi-select";
  };
  ComfyUI-Image-Saver = {
    url = "https://github.com/alexopus/ComfyUI-Image-Saver";
    rev = "1d2df13cfca0364fa28be3d40484cbeed33305ac";
    sha256 = "0kjvp6ccpqr5vja0x5f3c2waqv5mx0pyw49331f7fzfqhbszl74v";
    description = "Image Saver — save with Civitai-compatible generation metadata (PNG-Info, aesthetics)";
  };
  ComfyUI-Lora-Auto-Trigger-Words = {
    url = "https://github.com/idrirap/ComfyUI-Lora-Auto-Trigger-Words";
    rev = "38e89f95671e1dcdca86c9baf57ac2e1cb2f89e1";
    sha256 = "1hcx38mqx6myrbchxjkdcbyd6wn0vccqanj3xdx2cprln22figy2";
    description = "Lora Auto Trigger Words — auto-loads LoRA trigger words from metadata";
  };

  # ── Detailers / regional (Impact family) ────────────────────────────────
  ComfyUI-Impact-Pack = {
    url = "https://github.com/ltdrdata/ComfyUI-Impact-Pack";
    rev = "429d0159ad429e64d2b3916e6e7be9c22d025c3c";
    sha256 = "04nzrlasvza8a89jzva3440aikd5cgp1hj1wikhi17y00axbd2b6";
    description = "Impact Pack — Detector/Detailer (face & segment detail, SAM samplers, upscale pipes)";
  };
  ComfyUI-Impact-Subpack = {
    url = "https://github.com/ltdrdata/ComfyUI-Impact-Subpack";
    rev = "50c7b71a6a224734cc9b21963c6d1926816a97f1";
    sha256 = "0h7d036wim5q74z1g93laj8vqp4kar21kapb4wgndbg3s4cjd9ps";
    description = "Impact Sub Pack — required companion for Impact-Pack (SAM, GroundingDINO, detection utils)";
  };
  ComfyUI-Inspire-Pack = {
    url = "https://github.com/ltdrdata/ComfyUI-Inspire-Pack";
    rev = "d23db9aa544de9a6d4c609cb7005fa9e0d42031d";
    sha256 = "14w0cpjzd11983c39hiy6jhpd0l2fwg18jkvj9mdlhwp9kc7jday";
    description = "Inspire Pack — regional prompting, NoiseInjection, sampling selectors (from Impact author)";
  };

  # ── Upscale / layers / photo ────────────────────────────────────────────
  ComfyUI_UltimateSDUpscale = {
    url = "https://github.com/ssitu/ComfyUI_UltimateSDUpscale";
    rev = "a5547db9e1d07d3318bb21e9e9c474f4c1e9c8df";
    sha256 = "1ln9x232xjbirbig3xfrkz1ixnfngx046nmsq1nps0n4jy7zg549";
    description = "Ultimate SD Upscale — tiled upscale with the classic script's params";
  };
  ComfyUI_LayerStyle = {
    url = "https://github.com/chflame163/ComfyUI_LayerStyle";
    rev = "557d882e184c7b702208cc7805659b10dfa06c59";
    sha256 = "0kl8r5sfv22a8mhq8rfp8kqj5xq2qvldngqld8cw3kg19cr8bas4";
    description = "LayerStyle — Photoshop-like layer/composite node set";
  };

  # ── ControlNet / conditioning ───────────────────────────────────────────
  comfyui_controlnet_aux = {
    url = "https://github.com/Fannovel16/comfyui_controlnet_aux";
    rev = "59b1fc411ede8623b2997855b8018f0b3b6cf49f";
    sha256 = "11ca08n8j60pzywjwskndh67x2hwyb7plfy7cjfcg9hyl7ghdrkv";
    description = "ControlNet Auxiliary Preprocessors — lineart/depth/pose/seg/normal/mlsd/zoe etc";
  };
  ComfyUI-Advanced-ControlNet = {
    url = "https://github.com/Kosinkadink/ComfyUI-Advanced-ControlNet";
    rev = "27a67fee80cf46c198b10588a5651f23d67d1e95";
    sha256 = "18gyjhg1kpf3r4rwk0k25xv0gj3mwnlvsq7hbyhgkrglmjidg5s9";
    description = "Advanced ControlNet — scheduling & masking for CNets";
  };
  ComfyUI_IPAdapter_plus = {
    url = "https://github.com/cubiq/ComfyUI_IPAdapter_plus";
    rev = "a0f451a5113cf9becb0847b92884cb10cbdec0ef";
    sha256 = "0332f0jra155902l8n6h75hsm26vvacsn283nkv8kkm3r4jmdpqn";
    description = "IPAdapter plus — image-prompting adapters (style/face/transfer), the canonical pack";
  };

  # ── Video ───────────────────────────────────────────────────────────────
  ComfyUI-AnimateDiff-Evolved = {
    url = "https://github.com/Kosinkadink/ComfyUI-AnimateDiff-Evolved";
    rev = "9257651221002dcba0a12f9cff37e1944e58fb60";
    sha256 = "02i8d52pwhd78a32fndijhb6r875sv0al5f34vvrjzfr4xlzaj7h";
    description = "AnimateDiff Evolved — motion-module video gen + advanced sampling";
  };
  ComfyUI-VideoHelperSuite = {
    url = "https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite";
    rev = "4d907bee61e92c2e65af3bd6383a4e4d356126d1";
    sha256 = "0blmagk6y5am1d3zrpb3mxz1kq7xg9cmhc48yjadyx3agqc7qy5s";
    description = "Video Helper Suite — load/save/assemble video, frame interpolation utils";
  };
  ComfyUI-KJNodes = {
    url = "https://github.com/kijai/ComfyUI-KJNodes";
    rev = "e8e88f7c88e3f6205b122f5de87e69a09fbce5ac";
    sha256 = "100ac67fzic6gdzp39siq4aq73nnnqj68m3v7vi339gfs6kxkdgd";
    description = "KJNodes — kijai's utils: masks, latent, video, conditioning helpers";
  };

  # ── Captioning / vision ─────────────────────────────────────────────────
  ComfyUI-Florence2 = {
    url = "https://github.com/kijai/ComfyUI-Florence2";
    rev = "9ece3de914214c5f581d725167bc9d0eeb0d1120";
    sha256 = "140cw00w9127rl862hhhlgq6nfm9p5idzn5wj142wlbs32sjfl2f";
    description = "Florence2 — Microsoft VLM captioning & grounding nodes";
  };
  ComfyUI-WD14-Tagger = {
    url = "https://github.com/pythongosssss/ComfyUI-WD14-Tagger";
    rev = "9e0a6e700299182fc05c58b62e7ad9f72182a78b";
    sha256 = "0r7ifr3a7bbigbda59lbk23r6h5a5n1sb8m5akfr10krfjjwl3f3";
    description = "WD14 Tagger — booru-tag interrogation of images (captioning)";
  };

  # ── Model loading / quantization ────────────────────────────────────────
  ComfyUI-GGUF = {
    url = "https://github.com/city96/ComfyUI-GGUF";
    rev = "6ea2651e7df66d7585f6ffee804b20e92fb38b8a";
    sha256 = "1x866w03is9nkaagzj5zxj849jcbbi1788aw4wywlk2k1ir1x77x";
    description = "GGUF — quantized GGUF model loading (checkpoints/loras/clips) for low-VRAM inference";
  };

  # ── CivitAI compat ──────────────────────────────────────────────────────
  civitai_comfy_nodes = {
    url = "https://github.com/civitai/civitai_comfy_nodes";
    rev = "94949435eda6b03802471f837f45b99109041a6d";
    sha256 = "08rywsr7bs3wkb34hhfcbhnp2bwmij9ladflncbv49c4xcxywjca";
    description = "CivitAI (legacy local pack) — load models/LoRAs directly from Civitai by AIR ID (no API key)";
  };
  civitai-comfy-nodes = {
    url = "https://github.com/civitai/civitai-comfy-nodes";
    rev = "ee61d1ac0aac6febdd3ac0a13922e5cc7f164aab";
    sha256 = "18a32sg0sf7dhxcfy6dyh220dapy3a4mdqnigfsdildxj29wjifg";
    description = "CivitAI (official, orchestration) — cloud recipes image/video/audio gen via Civitai API (needs CIVITAI_API_TOKEN)";
  };
}