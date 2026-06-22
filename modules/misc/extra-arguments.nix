{
  lib,
  config,
  pkgs,
  ...
}:
{
  _module.args = {
    utils = import "${pkgs.path}/nixos/lib/utils.nix" { inherit pkgs lib config; };
  };
}
