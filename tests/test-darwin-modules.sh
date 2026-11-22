#!/bin/sh
set -eu

cd "$(dirname "$0")/.."
fqdn=$(nix eval --raw ./tests/flake-module#darwinConfigurations.test.config.networking.fqdn \
  --override-input nix-darwin . "$@")

if [ "$fqdn" != test-mac.example.org ]; then
  echo "Expected test-mac.example.org, got '$fqdn'" >&2
  exit 1
fi
