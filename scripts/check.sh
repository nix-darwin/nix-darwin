#!/usr/bin/env bash

set -euo pipefail

build_batch() {
  printf 'Building checks: %s\n' "${batch[*]}"
  nix build --no-link --no-write-lock-file "$@" "${batch[@]}"
  batch=()
}

system=$(nix eval --impure --raw --expr builtins.currentSystem)
checks=$(nix eval --json --no-write-lock-file "$@" \
  ".#checks.$system" --apply builtins.attrNames)

# Each build gets a fresh evaluator, so earlier tests do not retain memory.
batch=()
while IFS= read -r name; do
  batch+=(".#checks.$system.$name")
  if [[ ${#batch[@]} -eq 10 ]]; then
    build_batch "$@"
  fi
done < <(jq -r '.[]' <<< "$checks")

if [[ ${#batch[@]} -gt 0 ]]; then
  build_batch "$@"
fi

# Validate the other flake outputs without evaluating the tests again.
nixpkgs=$(nix flake archive --json --no-write-lock-file "$@" | jq -r '.inputs.nixpkgs.path')
nix flake check --no-build --no-write-lock-file ./scripts/ci-flake "$@" \
  --override-input nixpkgs "$nixpkgs"
