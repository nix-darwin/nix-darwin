{ config, lib, ... }:

with lib;

let
  inherit (config.lib.defaults.types) floatWithDeprecationError;
in
{
  options = {

    system.defaults.".GlobalPreferences"."com.apple.sound.beep.sound" =
      mkOption {
        type = types.nullOr (types.path);
        default = null;
        description = ''
          Sets the system-wide alert sound. Found under "Sound Effects" in the
          "Sound" section of "System Preferences". Look in
          "/System/Library/Sounds" for possible candidates.
        '';
      };

    system.defaults.".GlobalPreferences"."com.apple.mouse.scaling" =
      mkOption {
        type = types.nullOr floatWithDeprecationError;
        default = null;
        example = -1.0;
        description = ''
          Sets the mouse tracking speed. Found in the "Mouse" section of
          "System Preferences". Set to -1.0 to disable mouse acceleration.
        '';
      };

    system.defaults.".GlobalPreferences"."AppleICUNumberSymbols" =
      mkOption {
        type = types.nullOr types.attrs;
        default = null;
        example = {
          "0" = ".";
          "1" = ",";
          "10" = ".";
          "17" = ",";
        };
        description = lib.mdDoc ''
          Sets the number formatting for the system. For example, to use a
          comma as the decimal separator and a period as the thousands
          separator, set this to:
          
          {
            "0" = ".";
            "1" = ",";
            "10" = ".";
            "17" = ",";
          }.
        '';
      };
  };
}
