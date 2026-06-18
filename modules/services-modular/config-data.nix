# Sets `configData.<name>.path` for each service in the tree, mirroring
# the upstream `nixos/modules/system/service/systemd/config-data-path.nix`
# pattern but with a configurable root prefix so the same module can be
# reused for both system services (`/etc/system-services/...`) and user
# services (`${HOME}/.config/system-services/...`).
{ rootPath }:
let
  setPathsModule =
    prefix:
    { lib, name, ... }:
    let
      inherit (lib) mkOption types;
      servicePrefix = "${prefix}${name}";
    in
    {
      _class = "service";
      options = {
        configData = mkOption {
          type = types.lazyAttrsOf (
            types.submodule (
              { config, ... }:
              {
                config.path = lib.mkDefault "${rootPath}/${servicePrefix}/${config.name}";
              }
            )
          );
        };
        services = mkOption {
          type = types.attrsOf (
            types.submoduleWith {
              modules = [ (setPathsModule "${servicePrefix}-") ];
            }
          );
        };
      };
    };
in
setPathsModule ""
