#!/usr/bin/env bash

set -euo pipefail

git checkout master
git pull

version=$(jq -r .release version.json)

# branch off ${version}
echo "Cutting nix-darwin-${version} release branch"

git checkout -b "nix-darwin-${version}"

sed -i -e "s!- master!- nix-darwin-${version}!" .github/workflows/test.yml
sed -i -e "s!NIXPKGS_BRANCH: nixpkgs-unstable!NIXPKGS_BRANCH: nixpkgs-${version}-darwin!" .github/workflows/test.yml

sed -i -e "s!nixpkgs-unstable!nixpkgs-${version}-darwin!" modules/examples/flake/flake.nix
sed -i -e "s!github:nix-darwin/nix-darwin/master!github:nix-darwin/nix-darwin/nix-darwin-${version}!" modules/examples/flake/flake.nix

sed -i -e "s!nixpkgs/unstable!nixpkgs/stable!g" modules/nix/nixpkgs.nix

sed -i -e "s!nixpkgs-unstable!nixpkgs-${version}-darwin!" flake.nix
nix flake lock

cat <<EOF > README.md
# nix-darwin

This is the ${version} release branch of nix-darwin. See [the main readme](https://github.com/nix-darwin/nix-darwin#readme) for documentation
EOF

cat <<EOF > version.json
{
  "release": "${version}",
  "isReleaseBranch": true
}
EOF

git add .
git commit -m "version: branch off ${version}"

# update master
echo "Updating master to point to next version"

git checkout master

## update version.json to point to the next version

IFS='.' read -r major minor <<< "$version"

if [[ "$minor" = "11" ]]; then
    major=$(( major + 1 ))
    minor="05"
else
    minor="11"
fi

cat <<EOF > version.json
{
  "release": "${major}.${minor}",
  "isReleaseBranch": false
}
EOF

## update readme so that instructions refer to the version we're cutting (our supported stable version)

sed -i -e "s![0-9][0-9]\.[0-9][0-9]!${version}!g" README.md

git add .
git commit -m "version: bump to ${major}.${minor}"

nix flake update

git add .
git commit -m "flake.lock: update"
