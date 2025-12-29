{
  lib,
  flake-parts-lib,
  ...
}:
{
  options = {
    flake = flake-parts-lib.mkSubmoduleOptions {
      darwinConfigurations = lib.mkOption {
        type = lib.types.lazyAttrsOf lib.types.raw;
        default = { };
        description = "Darwin system configurations";
      };
    };
  };
}
