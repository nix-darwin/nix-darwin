#!/usr/bin/env bash

set -euo pipefail

sw_vers
if command -v nix >/dev/null; then
  nix --version
fi

# These macOS and installer files already have knownSha256Hashes in the modules.
files=(
  /etc/bashrc
  /etc/zprofile
  /etc/zshrc
  /etc/zshenv
  /etc/shells
  /etc/nix/nix.conf
)

for file in "${files[@]}"; do
  if [[ ! -f "$file" ]]; then
    echo "$file does not exist"
    continue
  fi

  echo "::group::$file"
  shasum -a 256 "$file"
  cat "$file"
  echo "::endgroup::"
done
