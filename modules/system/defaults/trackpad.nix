{ config, lib, ... }:

with lib;

{
  options = {

    system.defaults.trackpad.Clicking = mkOption {
      type = types.nullOr types.bool;
      default = null;
      description = ''
        Whether to enable tap to click. The default is false.
      '';
    };

    system.defaults.trackpad.Dragging = mkOption {
      type = types.nullOr types.bool;
      default = null;
      description = ''
        Whether to enable tap to drag. The default is false.
      '';
    };

    system.defaults.trackpad.TrackpadRightClick = mkOption {
      type = types.nullOr types.bool;
      default = null;
      description = ''
        Whether to enable trackpad right click (two-finger tap/click).
        The default is false.
      '';
    };

    system.defaults.trackpad.TrackpadThreeFingerDrag = mkOption {
      type = types.nullOr types.bool;
      default = null;
      description = ''
        Whether to enable three-finger drag. The default is false.
      '';
    };

    system.defaults.trackpad.ActuationStrength = mkOption {
      type = types.nullOr (types.enum [ 0 1 ]);
      default = null;
      description = ''
        0 to enable Silent Clicking, 1 to disable. The default is 1.
      '';
    };

    system.defaults.trackpad.FirstClickThreshold = mkOption {
      type = types.nullOr (types.enum [ 0 1 2 ]);
      default = null;
      description = ''
        For normal click: 0 for light clicking, 1 for medium, 2 for firm.
        The default is 1.
      '';
    };

    system.defaults.trackpad.SecondClickThreshold = mkOption {
      type = types.nullOr (types.enum [ 0 1 2 ]);
      default = null;
      description = ''
        For force touch: 0 for light clicking, 1 for medium, 2 for firm.
        The default is 1.
      '';
    };

    system.defaults.trackpad.TrackpadThreeFingerTapGesture = mkOption {
      type = types.nullOr (types.enum [ 0 2 ]);
      default = null;
      description = ''
        Whether to enable three-finger tap gesture: 0 to disable, 2 to trigger Look up & data detectors.
        The default is 2.
      '';
    };

    system.defaults.trackpad.ActuateDetents = mkOption {
      type = types.nullOr types.bool;
      default = null;
      description = ''
        Whether to enable haptic feedback. The default is true.
      '';
    };

    system.defaults.trackpad.DragLock = mkOption {
      type = types.nullOr types.bool;
      default = null;
      description = ''
        Whether to enable drag lock. The default is false.
      '';
    };

    system.defaults.trackpad.ForceSuppressed = mkOption {
      type = types.nullOr types.bool;
      default = null;
      description = ''
        Whether to disable force click. The default is false.
      '';
    };

    system.defaults.trackpad.TrackpadCornerSecondaryClick = mkOption {
      type = types.nullOr (types.enum [ 0 1 2 ]);
      default = null;
      description = ''
        Whether to enable secondary click: 0 to disable, 1 to set bottom-left corner, 2 to set bottom-right corner.
        The default is 0.
      '';
    };

    system.defaults.trackpad.TrackpadFourFingerHorizSwipeGesture = mkOption {
      type = types.nullOr (types.enum [ 0 2 ]);
      default = null;
      description = ''
        Whether to enable four-finger horizontal swipe gesture: 0 to disable, 2 to swipe between full-screen applications.
        The default is 0.
      '';
    };

    system.defaults.trackpad.TrackpadFourFingerPinchGesture = mkOption {
      type = types.nullOr (types.enum [ 0 2 ]);
      default = null;
      description = ''
        Whether to enable four-finger pinch gesture (spread shows the Desktop, pinch shows the Launchpad): 0 to disable, 2 to enable.
        The default is 0.
        This setting interacts with `system.defaults.dock.showDesktopGestureEnabled` and `system.defaults.dock.showLaunchpadGestureEnabled` to determine whether gestures are enabled for the Desktop, Launchpad, or both.
      '';
    };

    system.defaults.trackpad.TrackpadFourFingerVertSwipeGesture = mkOption {
      type = types.nullOr (types.enum [ 0 2 ]);
      default = null;
      description = ''
        0 to disable four finger vertical swipe gestures, 2 to enable (down for Mission Control, up for App Exposé).
        The default is 2.
        When both three- and four-finger vertical swipe gestures are enabled, the three-finger variant takes precedence. This setting interacts with `system.defaults.dock.showAppExposeGestureEnabled` and `system.defaults.dock.showMissionControlGestureEnabled` to determine whether vertical swipe gestures are enabled for App Exposé, Mission Control, or both. 
      '';
    };

    system.defaults.trackpad.TrackpadMomentumScroll = mkOption {
      type = types.nullOr types.bool;
      default = null;
      description = ''
        Whether to use inertia when scrolling. The default is true.
      '';
    };

    system.defaults.trackpad.TrackpadPinch = mkOption {
      type = types.nullOr types.bool;
      default = null;
      description = ''
        Whether to enable two-finger pinch gesture for zooming in and out.
        The default is false.
      '';
    };

    system.defaults.trackpad.TrackpadRotate = mkOption {
      type = types.nullOr types.bool;
      default = null;
      description = ''
        Whether to enable two-finger rotation gesture. The default is false.
      '';
    };

    system.defaults.trackpad.TrackpadThreeFingerHorizSwipeGesture = mkOption {
      type = types.nullOr (types.enum [ 0 1 2 ]);
      default = null;
      description = ''
        Whether to enable three-finger horizontal swipe gesture: 0 to disable, 1 to swipe between pages, 2 to swipe between full-screen applications.
        The default is 2.
      '';
    };

    system.defaults.trackpad.TrackpadThreeFingerVertSwipeGesture = mkOption {
      type = types.nullOr (types.enum [ 0 2 ]);
      default = null;
      description = ''
        Whether to enable three-finger vertical swipe gesture (down for Mission Control, up for App Exposé): 0 to disable, 2 to enable.
        The default is 2.
        This setting interacts with `system.defaults.dock.showAppExposeGestureEnabled` and `system.defaults.dock.showMissionControlGestureEnabled` to determine whether vertical swipe gestures are enabled for App Exposé, Mission Control, or both.
      '';
    };

    system.defaults.trackpad.TrackpadTwoFingerDoubleTapGesture = mkOption {
      type = types.nullOr types.bool;
      default = null;
      description = ''
        Whether to enable smart zoom when double-tapping with two fingers.
        The default is false.
      '';
    };

    system.defaults.trackpad.TrackpadTwoFingerFromRightEdgeSwipeGesture = mkOption {
      type = types.nullOr (types.enum [ 0 3 ]);
      default = null;
      description = ''
        Whether to enable two-finger swipe-from-right-edge gesture: 0 to disable, 3 to open Notification Center.
        The default is 0.
      '';
    };

  };
}
