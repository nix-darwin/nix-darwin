{
  # scripts/check.sh supplies the same Nixpkgs source used by the test batches.
  inputs.nixpkgs.url = "nixpkgs";

  # Test derivations are evaluated and built in batches by scripts/check.sh.
  outputs = inputs: builtins.removeAttrs ((import ../../flake.nix).outputs inputs) [ "checks" ];
}
