# Python packages required by ComfyUI custom nodes that are not in nixpkgs.
#
# These are built here so the custom-node Python environment is fully
# reproducible: no runtime `pip install` / ComfyUI-Manager installs.  Keep this
# file next to the ComfyUI module; each entry is pinned to an exact release
# (PyPI hash) or git commit (fetchgit hash).
{ pkgs, lib, python }:
let
  inherit (pkgs) fetchPypi fetchFromGitHub;
  inherit (python.pkgs) buildPythonPackage;

  # Torch/torchvision and OpenCV are supplied by ComfyUI's locked base
  # environment.  Do not pull nixpkgs' CUDA torch or the CUDA-enabled nixpkgs
  # OpenCV into the closure just to satisfy a node's metadata.
  stripTorch = deps: builtins.filter
    (d: !(builtins.elem (d.pname or "") [ "torch" "torchvision" "opencv-python" "opencv-python-headless" ]))
    deps;

  # ultralytics depends on torch/torchvision and its thop helper.  ComfyUI
  # already provides torch at runtime; strip the nixpkgs copies so the closure
  # does not grow by a second CUDA torch.
  ultralytics-thop = python.pkgs.ultralytics-thop.overridePythonAttrs (o: {
    dependencies = stripTorch o.dependencies;
    pythonImportsCheck = [ ];
    doCheck = false;
    dontCheckRuntimeDeps = true;
  });
  # nixpkgs' onnxruntime is a large cmake source build, and the flake's global
  # `cudaSupport = true` selects the CUDA variant (not in the binary cache).
  # The ONNX-based nodes (WD14 tagger, rembg) only need the CPU runtime, so
  # use the self-contained upstream CPU wheel and autoPatchelf it.  This
  # avoids the multi-hour source build entirely.
  onnxruntime = python.pkgs.onnxruntime.overridePythonAttrs (_: {
    version = "1.31.0";
    src = pkgs.fetchurl {
      url = "https://files.pythonhosted.org/packages/0d/ac/67ebbaab4b3083f2a6b27ee6c4aa400c7f8d6c72b5499aac7e4cd6ba74f5/onnxruntime-1.31.0-cp313-cp313-manylinux_2_28_x86_64.whl";
      sha256 = "37fd78cee5160c7a43a1730ccb3682ffd880af9c9e80385d625c0c2f8b125809";
    };
    # Let wheelUnpackHook unpack the wheel; the nixpkgs package overrides
    # unpackPhase because its `src` is the directory-shaped `dist` output.
    unpackPhase = "";
    # The wheel bundles libonnxruntime.so; drop the nixpkgs non-python
    # onnxruntime/onednn/re2/openvino inputs and patch the bundled libs.
    buildInputs = [ pkgs.stdenv.cc.cc.lib pkgs.zlib ];
    nativeBuildInputs = [ pkgs.autoPatchelfHook ];
    pythonImportsCheck = [ ];
    doCheck = false;
    dontCheckRuntimeDeps = true;
  });

  # numba's CUDA path pulls the CUDA toolkit (and changes the derivation hash
  # under the flake's global `cudaSupport = true`).  The node deps only need
  # the CPU JIT, so pin the CPU build that is in the binary cache.
  numba = python.pkgs.numba.override { cudaSupport = false; };

  # pymatting's CUDA path pulls cupy + pyopencl (large uncached CUDA source
  # builds).  ComfyUI's LayerStyle / rembg usage works on the CPU path.
  pymatting = python.pkgs.pymatting.override {
    cudaSupport = false;
    inherit numba;
  };

  # imageio's test-only pillow-heif dependency pulls nixpkgs OpenCV built with
  # CUDA (a huge uncached build).  Runtime imageio only needs numpy/pillow.
  imageio = python.pkgs.imageio.overridePythonAttrs (o: {
    doCheck = false;
    nativeCheckInputs = builtins.filter
      (d: (d.pname or "") != "pillow-heif")
      (o.nativeCheckInputs or [ ]);
  });

  # Keep scikit-image on the lean imageio above.
  scikit-image = python.pkgs.scikit-image.override { inherit imageio; };

  # scikit-learn's full test suite dominates the build time and is irrelevant
  # to node runtime behaviour.
  scikit-learn = python.pkgs.scikit-learn.overridePythonAttrs (_: {
    doCheck = false;
  });

  # rembg pulls pymatting, onnxruntime and scikit-image; point it at the CPU
  # variants above.
  rembg = python.pkgs.rembg.override {
    inherit pymatting onnxruntime scikit-image;
    cudaSupport = false;
  };
in
{
  inherit ultralytics-thop onnxruntime numba pymatting imageio scikit-image scikit-learn rembg;

  ultralytics = python.pkgs.ultralytics.overridePythonAttrs (o: {
    dependencies = map
      (d: if (d.pname or "") == "ultralytics-thop" then ultralytics-thop else d)
      (stripTorch o.dependencies);
    pythonImportsCheck = [ ];
    doCheck = false;
    dontCheckRuntimeDeps = true;
  });

  fairscale = python.pkgs.fairscale.overridePythonAttrs (o: {
    propagatedBuildInputs = stripTorch o.propagatedBuildInputs;
    pythonImportsCheck = [ ];
    dontCheckRuntimeDeps = true;
  });
  segment-anything = buildPythonPackage rec {
    pname = "segment-anything";
    version = "1.0";
    format = "setuptools";

    src = fetchPypi {
      pname = "segment_anything";
      inherit version;
      sha256 = "0svk0djjcr70wdrwl1b3dfxg2wl27jhjhw4a4g3gkgkvn1pry37d";
    };

    # The package's own install_requires is empty; these are the runtime
    # imports used by its AMG/SAM helpers.  torch/opencv come from ComfyUI.
    dependencies = [
      python.pkgs.numpy
      python.pkgs.pycocotools
    ];

    doCheck = false;
    pythonImportsCheck = [ ];
    meta = {
      description = "Meta Segment Anything Model (SAM)";
      homepage = "https://github.com/facebookresearch/segment-anything";
      license = lib.licenses.asl20;
    };
  };

  colour-science = buildPythonPackage rec {
    pname = "colour-science";
    version = "0.4.7";
    pyproject = true;
    build-system = [ python.pkgs.hatchling ];

    src = fetchPypi {
      pname = "colour_science";
      inherit version;
      sha256 = "0yahzl6rggmcilqa5cwlv4s22lwz1shpyad5rjcvmyfk9pf76ixk";
    };

    dependencies = [
      python.pkgs.numpy
      python.pkgs.scipy
      python.pkgs.matplotlib
    ];

    doCheck = false;
    pythonImportsCheck = [ ];
    meta = {
      description = "Colour Science for Python";
      homepage = "https://www.colour-science.org";
      license = lib.licenses.bsd3;
    };
  };

  blend-modes = buildPythonPackage rec {
    pname = "blend-modes";
    version = "2.2.0";
    format = "setuptools";

    src = fetchPypi {
      pname = "blend_modes";
      inherit version;
      sha256 = "0fhj5iv1dql3a8bwj88bd45g4fmxzchjmrcjyx5ak5rhx0xp1q2l";
    };

    dependencies = [ python.pkgs.numpy ];

    doCheck = false;
    pythonImportsCheck = [ ];
    meta = {
      description = "Image blending modes for Python";
      homepage = "https://github.com/flrs/blend_modes";
      license = lib.licenses.mit;
    };
  };

  pilgram = buildPythonPackage rec {
    pname = "pilgram";
    version = "2.0.0";
    pyproject = true;
    build-system = [ python.pkgs.hatchling ];

    src = fetchPypi {
      pname = "pilgram";
      inherit version;
      sha256 = "12j9f86q3biv0xf3brlhpvzx50qjayhr953lvcmpz9snfarsx0vj";
    };

    dependencies = [
      python.pkgs.numpy
      python.pkgs.pillow
    ];

    doCheck = false;
    pythonImportsCheck = [ ];
    meta = {
      description = "Instagram-like image filters";
      homepage = "https://github.com/akiomik/pilgram";
      license = lib.licenses.asl20;
    };
  };

  img2texture = buildPythonPackage rec {
    pname = "img2texture";
    version = "1.0.6";
    format = "setuptools";

    src = fetchFromGitHub {
      owner = "WASasquatch";
      repo = "img2texture";
      rev = "d6159abea44a0b2cf77454d3d46962c8b21eb9d3";
      sha256 = "0kpirm765wrr06znb0h547wf8njm2k3jf0fmkssiryp037srxjg7";
    };

    dependencies = [ python.pkgs.pillow ];

    doCheck = false;
    pythonImportsCheck = [ ];
    meta = {
      description = "Convert images to seamless tiles";
      homepage = "https://github.com/WASasquatch/img2texture";
      license = lib.licenses.mit;
    };
  };

  cstr = buildPythonPackage rec {
    pname = "cstr";
    version = "0.1.0";
    format = "setuptools";

    src = fetchFromGitHub {
      owner = "WASasquatch";
      repo = "cstr";
      rev = "0520c29a18a7a869a6e5983861d6f7a4c86f8e9b";
      sha256 = "1fm22x63ijqszc3a38f7hdfglhbx16pwdkz8b9j5a81v966yf06d";
    };

    dependencies = [ ];

    doCheck = false;
    pythonImportsCheck = [ ];
    meta = {
      description = "Colored console strings";
      homepage = "https://github.com/WASasquatch/cstr";
      license = lib.licenses.mit;
    };
  };
}
