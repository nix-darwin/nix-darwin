{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.system.startup;
in

{
  meta.maintainers = [
    lib.maintainers.samasaur or "samasaur"
  ];

  options = {
    system.startup.chime = lib.mkOption {
      type = with lib.types; nullOr bool;
      default = null;
      example = false;
      description = ''
        Whether to enable the startup chime.

        By default, this option does not affect your system configuration in any way.
        However, this means that after it has been set once, unsetting it will not
        return to the old behavior. It will allow the setting to be controlled in
        System Settings, though.
      '';
    };
  };

  config = {
    system.nvram.variables."StartupMute" = lib.mkIf (cfg.chime != null) (
      if cfg.chime then "%00" else "%01"
    );
  };
}
