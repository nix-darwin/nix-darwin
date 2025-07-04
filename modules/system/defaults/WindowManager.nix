{ config, lib, ... }:

with lib;
{
  options = {
    system.defaults.WindowManager.GloballyEnabled = mkOption {
      type = types.nullOr types.bool;
      default = null;
      description = ''
        Enable Stage Manager
        Stage Manager arranges your recent windows into a single strip for reduced clutter and quick access. Default is false.
      '';
    };

    system.defaults.WindowManager.EnableStandardClickToShowDesktop = mkOption {
      type = types.nullOr types.bool;
      default = null;
      description = ''
        Click wallpaper to reveal desktop
        Clicking your wallpaper will move all windows out of the way to allow access to your desktop items and widgets. Default is true.
        false means "Only in Stage Manager"
        true means "Always"
      '';
    };

    system.defaults.WindowManager.AutoHide = mkOption {
      type = types.nullOr types.bool;
      default = null;
      description = ''
        Auto hide stage strip showing recent apps. Default is false.
      '';
    };

    system.defaults.WindowManager.AppWindowGroupingBehavior = mkOption {
      type = types.nullOr types.bool;
      default = null;
      description = ''
        Grouping strategy when showing windows from an application.
        false means "One at a time"
        true means "All at once"
      '';
    };

    system.defaults.WindowManager.StandardHideDesktopIcons = mkOption {
      type = types.nullOr types.bool;
      default = null;
      description = ''
        Hide items on desktop.
      '';
    };

    system.defaults.WindowManager.HideDesktop = mkOption {
      type = types.nullOr types.bool;
      default = null;
      description = ''
        Hide items in Stage Manager.
      '';
    };

    system.defaults.WindowManager.EnableTilingByEdgeDrag = mkOption {
      type = types.nullOr types.bool;
      default = null;
      description = ''
        Enable dragging windows to screen edges to tile them. The default is true.
      '';
    };

    system.defaults.WindowManager.EnableTopTilingByEdgeDrag = mkOption {
      type = types.nullOr types.bool;
      default = null;
      description = ''
        Enable dragging windows to the menu bar to fill the screen. The default is true.
      '';
    };

    system.defaults.WindowManager.EnableTilingOptionAccelerator = mkOption {
      type = types.nullOr types.bool;
      default = null;
      description = ''
        Enable holding alt to tile windows. The default is true.
      '';
    };

    system.defaults.WindowManager.EnableTiledWindowMargins = mkOption {
      type = types.nullOr types.bool;
      default = null;
      description = ''
        Enable window margins when tiling windows. The default is true.
      '';
    };

    system.defaults.WindowManager.StandardHideWidgets = mkOption {
      type = types.nullOr types.bool;
      default = null;
      description = ''
        Hide widgets on desktop.
      '';
    };

    system.defaults.WindowManager.StageManagerHideWidgets = mkOption {
      type = types.nullOr types.bool;
      default = null;
      description = ''
        Hide widgets in Stage Manager.
      '';
    };
  };
}
