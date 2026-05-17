# Check that nixpkgs.config.allowUnfreePackages is merged correctly
# run with: nix-build release.nix -A tests.nixpkgs-config-allow-unfree
{
  config,
  lib,
  pkgs,
  ...
}:

{
  # Module 1: Define some unfree packages
  nixpkgs.config.allowUnfreePackages = [
    "vscode"
    "slack"
  ];

  # Module 2: Define more unfree packages (simulating multiple modules)
  # In a real scenario, this would be in a separate file
  imports = [
    (
      { config, ... }:
      {
        nixpkgs.config.allowUnfreePackages = [
          "zoom"
          "discord"
        ];
      }
    )
  ];

  test = ''
    echo checking allowUnfreePackages merging >&2

    # Verify that all packages from both modules are present
    expected_packages=("discord" "slack" "vscode" "zoom")
    actual_packages=(${builtins.toString (builtins.sort builtins.lessThan config.nixpkgs.config.allowUnfreePackages)})

    for pkg in "''${expected_packages[@]}"; do
      if [[ ! " ''${actual_packages[@]} " =~ " $pkg " ]]; then
        echo "ERROR: Expected package '$pkg' not found in allowUnfreePackages" >&2
        exit 1
      fi
    done
  '';
}
