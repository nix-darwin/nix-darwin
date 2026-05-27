{
  lib,
  config,
  pkgs,
  nixpkgs,
  ...
}:
{
  _module.args = {
    utils = import "${nixpkgs}/nixos/lib/utils.nix" { inherit pkgs lib config; };
  };
}
