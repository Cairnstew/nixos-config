{ lib, python312Packages, ... }:

python312Packages.buildPythonApplication rec {
  pname = "ipxe-installer";
  version = "0.1.0";
  src = ./.;
  pyproject = true;
  build-system = [ python312Packages.hatchling ];
  dependencies = with python312Packages; [
    typer
    jinja2
    pyyaml
    requests
    pydantic
  ];
  nativeCheckInputs = with python312Packages; [ pytest pytest-cov ];
  doCheck = false;  # tests need network access
  pythonImportsCheck = [ "ipxe_installer" ];
}
