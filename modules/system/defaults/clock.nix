{ config, lib, ... }:

with lib;

{
  options = {

    system.defaults.menuExtraClock.FlashDateSeparators = mkOption {
      type = types.nullOr types.bool;
      default = null;
      description = ''
        When enabled, the clock indicator (which by default is the colon) will flash on and off each second. Default is null.
      '';
    };

    system.defaults.menuExtraClock.IsAnalog = mkOption {
      type = types.nullOr types.bool;
      default = null;
      description = ''
        Show an analog clock instead of a digital one. Default is null.
      '';
    };

    system.defaults.menuExtraClock.Show24Hour = mkOption {
      type = types.nullOr types.bool;
      default = null;
      description = ''
        Show a 24-hour clock, instead of a 12-hour clock. Default is null.
      '';
    };

    system.defaults.menuExtraClock.ShowAMPM = mkOption {
      type = types.nullOr types.bool;
      default = null;
      description = ''
        Show the AM/PM label. Useful if Show24Hour is false. Default is null.
      '';
    };

    system.defaults.menuExtraClock.ShowDayOfMonth = mkOption {
      type = types.nullOr types.bool;
      default = null;
      description = ''
        Show the day of the month. Default is null.
      '';
    };

    system.defaults.menuExtraClock.ShowDayOfWeek = mkOption {
      type = types.nullOr types.bool;
      default = null;
      description = ''
        Show the day of the week. Default is null.
      '';
    };

    system.defaults.menuExtraClock.ShowDate = mkOption {
      type = types.nullOr (types.enum [ 0 1 2 ]);
      default = null;
      description = ''
        Show the full date. Default is null.

        0 = When space allows
        1 = Always
        2 = Never
      '';
    };

    system.defaults.menuExtraClock.ShowSeconds = mkOption {
      type = types.nullOr types.bool;
      default = null;
      description = ''
        Show the clock with second precision, instead of minutes. Default is null.
      '';
    };

    system.defaults.menuExtraClock.FlashDateSeparators = mkOption {
      type = types.nullOr types.bool;
      default = null;
      description = ''
        When enabled, the time separators will flash on and off each second.
      '';
    };

  };
}
