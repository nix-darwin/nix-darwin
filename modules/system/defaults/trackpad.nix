{ config, lib, ... }:

with lib;

{
  options = {

    system.defaults.trackpad.Clicking = mkOption {
      type = types.nullOr types.bool;
      default = null;
      description = ''
        Whether to enable trackpad tap to click.  The default is false.
      '';
    };

    system.defaults.trackpad.Dragging = mkOption {
      type = types.nullOr types.bool;
      default = null;
      description = ''
        Whether to enable tap-to-drag. The default is false.
      '';
    };

    system.defaults.trackpad.TrackpadRightClick = mkOption {
      type = types.nullOr types.bool;
      default = null;
      description = ''
        Whether to enable trackpad right click.  The default is false.
      '';
    };

    system.defaults.trackpad.TrackpadThreeFingerDrag = mkOption {
      type = types.nullOr types.bool;
      default = null;
      description = ''
        Whether to enable three finger drag.  The default is false.
      '';
    };

    system.defaults.trackpad.ActuationStrength = mkOption {
      type = types.nullOr (
        types.enum [
          0
          1
        ]
      );
      default = null;
      description = ''
        0 to enable Silent Clicking, 1 to disable.  The default is 1.
      '';
    };

    system.defaults.trackpad.FirstClickThreshold = mkOption {
      type = types.nullOr (
        types.enum [
          0
          1
          2
        ]
      );
      default = null;
      description = ''
        For normal click: 0 for light clicking, 1 for medium, 2 for firm.
        The default is 1.
      '';
    };

    system.defaults.trackpad.SecondClickThreshold = mkOption {
      type = types.nullOr (
        types.enum [
          0
          1
          2
        ]
      );
      default = null;
      description = ''
        For force touch: 0 for light clicking, 1 for medium, 2 for firm.
        The default is 1.
      '';
    };

    system.defaults.trackpad.TrackpadThreeFingerTapGesture = mkOption {
      type = types.nullOr (
        types.enum [
          0
          2
        ]
      );
      default = null;
      description = ''
        0 to disable three finger tap, 2 to trigger Look up & data detectors.
        The default is 2.
      '';
    };

  };
}
