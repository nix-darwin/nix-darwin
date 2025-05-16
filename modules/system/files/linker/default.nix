{ lib, python3Packages }:

python3Packages.buildPythonApplication {
  pname = "linker";
  version = "0.1.0";
  pyproject = true;

  src = ./.;

  build-system = [ python3Packages.poetry-core ];

  nativeCheckInputs = [
    python3Packages.pytestCheckHook
  ];

  meta = {
    description = "Link files into place across a nix-darwin system";
    maintainers = [ lib.maintainers.samasaur ];
    mainProgram = "linker";
    platforms = lib.platforms.darwin;
  };
}
