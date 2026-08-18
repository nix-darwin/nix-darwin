{ config, lib, ... }:

with lib;

{
  options = {

    system.defaults.universalaccess.mouseDriverCursorSize = mkOption {
      type = types.nullOr types.float;
      default = null;
      example = 1.5;
      description = ''
        Set the size of cursor. 1 for normal, 4 for maximum.
        The default is 1.
      '';
    };

    system.defaults.universalaccess.reduceMotion = mkOption {
      type = types.nullOr types.bool;
      default = null;
      description = ''
        Disable animation when switching screens or opening apps
      '';
    };

    system.defaults.universalaccess.reduceTransparency = mkOption {
      type = types.nullOr types.bool;
      default = null;
      description = ''
        Disable transparency in the menu bar and elsewhere.
        The default is false.
      '';
    };

    system.defaults.universalaccess.closeViewScrollWheelToggle = mkOption {
      type = types.nullOr types.bool;
      default = null;
      description = ''
        Use scroll gesture with the Ctrl (^) modifier key to zoom.
        The default is false.
      '';
    };

    system.defaults.universalaccess.closeViewZoomFollowsFocus = mkOption {
      type = types.nullOr types.bool;
      default = null;
      description = ''
        Follow the keyboard focus while zoomed in.
        Without setting `closeViewScrollWheelToggle` this has no effect.
        The default is false.
      '';
    };

    system.defaults.universalaccess.showWindowTitlebarIcons = mkOption {
      type = types.nullOr types.bool;
      default = null;
      description = ''
        Always show folder icon before title in the title bar
      '';
    };

  };
}
