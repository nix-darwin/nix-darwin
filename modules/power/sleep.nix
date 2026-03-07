{ config, lib, ... }:

let
  cfg = config.power.sleep;

  types = lib.types;

  onOff = cond: if cond then "on" else "off";
in

{
  options = {
    power.sleep.computer = lib.mkOption {
      type = types.nullOr (types.either types.ints.positive (types.enum [ "never" ]));
      default = null;
      example = "never";
      description = ''
        Amount of idle time (in minutes) until the computer sleeps.

        `"never"` disables computer sleeping.

        The system might not be considered idle before connected displays sleep, as
        per the `power.sleep.display` option.
      '';
    };

    power.sleep.display = lib.mkOption {
      type = types.nullOr (types.either types.ints.positive (types.enum [ "never" ]));
      default = null;
      example = "never";
      description = ''
        Amount of idle time (in minutes) until displays sleep.

        `"never"` disables display sleeping.
      '';
    };

    power.sleep.harddisk = lib.mkOption {
      type = types.nullOr (types.either types.ints.positive (types.enum [ "never" ]));
      default = null;
      example = "never";
      description = ''
        Amount of idle time (in minutes) until hard disks sleep.

        `"never"` disables hard disk sleeping.
      '';
    };

    power.sleep.allowSleepByPowerButton = lib.mkOption {
      type = types.nullOr types.bool;
      default = null;
      description = ''
        Whether the power button can sleep the computer.
      '';
    };
  };

  config = {

    system.activationScripts.power.text = lib.mkAfter ''
      ${lib.optionalString (cfg.computer != null) ''
        systemsetup -setComputerSleep '${toString cfg.computer}' &> /dev/null
      ''}

      ${lib.optionalString (cfg.display != null) ''
        systemsetup -setDisplaySleep '${toString cfg.display}' &> /dev/null
      ''}

      ${lib.optionalString (cfg.harddisk != null) ''
        systemsetup -setHardDiskSleep '${toString cfg.harddisk}' &> /dev/null
      ''}

      ${lib.optionalString (cfg.allowSleepByPowerButton != null) ''
        systemsetup -setAllowPowerButtonToSleepComputer \
          '${onOff cfg.allowSleepByPowerButton}' &> /dev/null
      ''}
    '';

  };
}
