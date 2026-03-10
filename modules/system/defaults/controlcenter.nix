{ config, lib, ... }:

{
  options = {

    system.defaults.controlcenter.BatteryShowPercentage = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      description = ''
        Apple menu > System Preferences > Control Center > Battery

        Show a battery percentage in menu bar. Default is null.
      '';
    };

    system.defaults.controlcenter.Sound = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      apply =
        v:
        if v == null then
          null
        else if v == true then
          18
        else
          24;
      default = null;
      description = ''
        Apple menu > System Preferences > Control Center > Sound

        Show a sound control in menu bar . Default is null.

        18 = Display icon in menu bar
        24 = Hide icon in menu bar
      '';
    };

    system.defaults.controlcenter.Bluetooth = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      apply =
        v:
        if v == null then
          null
        else if v == true then
          18
        else
          24;
      default = null;
      description = ''
        Apple menu > System Preferences > Control Center > Bluetooth

        Show a bluetooth control in menu bar. Default is null.

        18 = Display icon in menu bar
        24 = Hide icon in menu bar
      '';
    };

    system.defaults.controlcenter.AirDrop = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      apply =
        v:
        if v == null then
          null
        else if v == true then
          18
        else
          24;
      default = null;
      description = ''
        Apple menu > System Preferences > Control Center > AirDrop

        Show a AirDrop control in menu bar. Default is null.

        18 = Display icon in menu bar
        24 = Hide icon in menu bar
      '';
    };

    system.defaults.controlcenter.Display = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      apply =
        v:
        if v == null then
          null
        else if v == true then
          18
        else
          24;
      default = null;
      description = ''
        Apple menu > System Preferences > Control Center > Display

        Show a Screen Brightness control in menu bar. Default is null.

        18 = Display icon in menu bar
        24 = Hide icon in menu bar
      '';
    };

    system.defaults.controlcenter.FocusModes = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      apply =
        v:
        if v == null then
          null
        else if v == true then
          18
        else
          24;
      default = null;
      description = ''
        Apple menu > System Preferences > Control Center > Focus

        Show a Focus control in menu bar. Default is null.

        18 = Display icon in menu bar
        24 = Hide icon in menu bar
      '';
    };

    system.defaults.controlcenter.NowPlaying = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      apply =
        v:
        if v == null then
          null
        else if v == true then
          18
        else
          24;
      default = null;
      description = ''
        Apple menu > System Preferences > Control Center > Now Playing

        Show a Now Playing control in menu bar. Default is null.

        18 = Display icon in menu bar
        24 = Hide icon in menu bar
      '';
    };
  };
}
