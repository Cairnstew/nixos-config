{ config, lib, ... }:
let
  cfg = config.my.services.comfyui;

  # Same normalization + URN parser as config.nix (validates what the service
  # script will actually run). A plain string value is the URN shorthand.
  modelEntries = lib.mapAttrs
    (name: e:
      if builtins.isString e
      then { urn = e; enable = true; mode = null; type = null; url = null; sha256 = null; }
      else e)
    cfg.models;
  enabledModels = lib.filterAttrs (_: e: e.enable) modelEntries;

  urnFolder = {
    checkpoint = "checkpoints";
    lora = "loras";
    vae = "vae";
    clip = "clip";
    text_encoder = "text_encoders";
    textencoders = "text_encoders";
    diffusion_model = "diffusion_models";
    diffusionmodel = "diffusion_models";
    embedding = "embeddings";
    controlnet = "controlnet";
    upscale_model = "upscale_models";
    upscalemodel = "upscale_models";
    unet = "unet";
  };
  parseCivitaiUrn = urn:
    let
      parts = lib.splitString ":" urn;
      idPart = if builtins.length parts == 6 then builtins.elemAt parts 5 else "";
      verFile = lib.splitString "+" idPart;
      modVer = lib.splitString "@" (builtins.head verFile);
    in
    {
      schema = if builtins.length parts >= 2 then "${builtins.elemAt parts 0}:${builtins.elemAt parts 1}" else null;
      typePart = if builtins.length parts == 6 then builtins.elemAt parts 3 else null;
      source = if builtins.length parts == 6 then builtins.elemAt parts 4 else null;
      versionId = if builtins.length modVer == 2 then builtins.elemAt modVer 1 else null;
    };
  resolved = lib.imap1 (i: e: { index = i; inherit e; urnInfo = if e.urn != null then parseCivitaiUrn e.urn else null; })
    (lib.attrValues enabledModels);
in
{
  assertions = [
    {
      assertion = !cfg.enable || cfg.port > 0;
      message = "my.services.comfyui.port must be a valid port number.";
    }
    {
      assertion = !cfg.enable || cfg.dataDir != "";
      message = "my.services.comfyui.dataDir must not be empty.";
    }
    {
      assertion = !cfg.enable || !cfg.enableManager || cfg.manager.url != "";
      message = "my.services.comfyui.enableManager requires a manager source (my.services.comfyui.manager.url).";
    }
    {
      assertion = !cfg.enable || !cfg.enableManager || (cfg.manager.rev == null) == (cfg.manager.sha256 == null);
      message = ''
        my.services.comfyui.manager: rev and sha256 must be set together.
        - both null     → builtins.fetchGit (convenience, impure)
        - both set      → pkgs.fetchgit (locked, pure) — values from `nix-prefetch-git <url> <rev>`
      '';
    }
    {
      assertion = !cfg.enable || lib.all (n: n.url != "") (lib.attrValues (lib.filterAttrs (_: n: n.enable) cfg.customNodes));
      message = "my.services.comfyui.customNodes: each enabled node must have a non-empty url.";
    }
    {
      assertion = !cfg.enable || lib.all
        (n: (n.rev == null) == (n.sha256 == null))
        (lib.attrValues (lib.filterAttrs (_: n: n.enable) cfg.customNodes));
      message = ''
        my.services.comfyui.customNodes: rev and sha256 must be set together.
        - both null     → builtins.fetchGit (convenience, impure)
        - both set      → pkgs.fetchgit (locked, pure) — values from `nix-prefetch-git <url> <rev>`
      '';
    }
    {
      assertion = !cfg.enable || cfg.civitaiApiKeyPath == null || lib.hasPrefix "/" (toString cfg.civitaiApiKeyPath);
      message = "my.services.comfyui.civitaiApiKeyPath must be an absolute path to the key file (e.g. config.age.secrets.\"civitai-key\".path).";
    }
    {
      assertion = !cfg.enable || lib.all (p: lib.hasAttr p (import ./catalog.nix)) cfg.presets;
      message = ''
        my.services.comfyui.presets: unknown catalog name(s):
        ${lib.concatStringsSep ", " (lib.filter (p: !lib.hasAttr p (import ./catalog.nix)) cfg.presets)}
        Valid names: ${lib.concatStringsSep ", " (lib.attrNames (import ./catalog.nix))}
      '';
    }
    # ── Models ──────────────────────────────────────────────────────────────
    {
      assertion = !cfg.enable || lib.all (e: e.urn != null || e.url != null) (lib.attrValues enabledModels);
      message = ''
        my.services.comfyui.models: each enabled model needs a source —
        either `urn` (e.g. "urn:air:krea2:checkpoint:civitai:2723583@3060999+2939623")
        or `url` (with `type`, plus `sha256` in store mode).
      '';
    }
    {
      assertion = !cfg.enable || lib.all (e: e.urn == null || e.url == null) (lib.attrValues enabledModels);
      message = "my.services.comfyui.models: a model cannot set both `urn` and `url` (pick one source).";
    }
    {
      assertion = !cfg.enable || lib.all (e: e.urn != null -> (e.urnInfo.schema == "urn:air" && builtins.length (lib.splitString ":" e.urn) == 6 && e.urnInfo.source == "civitai" && e.urnInfo.versionId != null)) (lib.map (x: { urn = x.e.urn; urnInfo = x.urnInfo; }) resolved);
      message = ''
        my.services.comfyui.models: invalid URN — expected
        urn:air:<family>:<type>:civitai:<modelId>@<versionId>[+<fileId>]
        (only the `civitai` source is supported; <versionId> is required).
      '';
    }
    {
      assertion = !cfg.enable || lib.all
        (x: x.e.type != null || (x.urnInfo.typePart != null && lib.hasAttr x.urnInfo.typePart urnFolder))
        resolved;
      message = ''
        my.services.comfyui.models: cannot resolve a model folder — set `type`
        (e.g. "checkpoints") or use a URN whose <type> word maps to a folder
        (${lib.concatStringsSep ", " (lib.attrNames urnFolder)}).
      '';
    }
    {
      assertion = !cfg.enable || lib.all
        (e:
          let mode = if e.mode != null then e.mode else (if e.urn != null then "download" else "store"); in
          mode == "download" || (e.sha256 != null && e.url != null))
        (lib.attrValues enabledModels);
      message = ''
        my.services.comfyui.models: store mode requires both `url` and `sha256`
        (a pure build-time fixed-output fetch needs a pinned hash).
        For big civitai models prefer omitting them and letting the URN imply
        download mode (real file on the data disk, hash optional).
      '';
    }
  ];
}
