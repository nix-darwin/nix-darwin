{ config, lib, ... }:

{
  options = {
    system.defaults.Spotlight.MenuItemHidden = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      description = ''
        Apple menu > System Preferences > Control Center > Menu Bar Only > Spotlight

        Show Spotlight in menu bar. Default is null.

        false - "Don't Show in Menu Bar"
        true  - "Show in Menu Bar"
      '';
    };
  };
}
