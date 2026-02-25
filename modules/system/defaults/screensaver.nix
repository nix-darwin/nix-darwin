{ config, lib, ... }:

with lib;

{
  options = {

    system.defaults.screensaver.askForPassword = mkOption {
      type = types.nullOr types.bool;
      default = null;
      description = ''
        If true, the user is prompted for a password when the screen saver is unlocked or stopped. The default is false.
      '';
    };

    system.defaults.screensaver.askForPasswordDelay = mkOption {
      type = types.nullOr types.int;
      default = null;
      description = ''
        The number of seconds to delay before the password will be required to unlock or stop the screen saver (the grace period).
      '';
    };
  };
}
