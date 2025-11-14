{ config, lib, ... }:

{
  options = {
    system.defaults.Spotlight.MenuItemHidden = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      description = ''
        Show Spotlight control in menu bar.

        Available settings:
          true   - Don't Show in Menu Bar
          false  - Show in Menu Bar

        This option mirrors the setting found in:
          System Preferences > Control Center > Menu Bar Only > Spotlight
      '';
    };
  };
}