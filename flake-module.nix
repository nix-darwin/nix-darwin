{
  lib,
  ...
}:
{
  options.flake = {
    darwinConfigurations = lib.mkOption {
      type = lib.types.lazyAttrsOf lib.types.raw;
      default = { };
      description = "Darwin system configurations";
    };
    darwinModules = lib.mkOption {
      type = lib.types.lazyAttrsOf lib.types.raw;
      default = { };
      description = ''
        Darwin Modules

        You may use this for reusable pieces of configuration, service modules, etc.
      '';
    };
  };
}
