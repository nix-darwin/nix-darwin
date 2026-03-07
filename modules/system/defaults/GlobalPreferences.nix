{ config, lib, ... }:

with lib;

let
  inherit (config.lib.defaults.types) floatWithDeprecationError;
in
{
  options = {

    system.defaults.".GlobalPreferences"."com.apple.sound.beep.sound" = mkOption {
      type = types.nullOr (types.path);
      default = null;
      description = ''
        Sets the system-wide alert sound. Found under "Sound Effects" in the
        "Sound" section of "System Preferences". Look in
        "/System/Library/Sounds" for possible candidates.
      '';
    };

    system.defaults.".GlobalPreferences"."com.apple.mouse.scaling" = mkOption {
      type = types.nullOr floatWithDeprecationError;
      default = null;
      example = -1.0;
      description = ''
        Sets the mouse tracking speed. Found in the "Mouse" section of
        "System Preferences". Set to -1.0 to disable mouse acceleration.
      '';
    };
  };
}
