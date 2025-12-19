{ config, lib, ... }:

let
  inherit (lib) mkOption types;

  cfg = config.system.defaults.finder;
in
{
  options = {

    system.defaults.finder.AppleShowAllFiles = mkOption {
      type = types.nullOr types.bool;
      default = null;
      description = ''
        Whether to always show hidden files. The default is false.
      '';
    };

    system.defaults.finder.ShowStatusBar = mkOption {
      type = types.nullOr types.bool;
      default = null;
      description = ''
        Show status bar at bottom of finder windows with item/disk space stats. The default is false.
      '';
    };

    system.defaults.finder.ShowPathbar = mkOption {
      type = types.nullOr types.bool;
      default = null;
      description = ''
        Show path breadcrumbs in finder windows. The default is false.
      '';
    };

    system.defaults.finder.FXDefaultSearchScope = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''
        Change the default search scope. Use "SCcf" to default to current folder.
        The default is unset ("This Mac").
      '';
    };

    system.defaults.finder.FXRemoveOldTrashItems = mkOption {
      type = types.nullOr types.bool;
      default = null;
      description = ''
        Remove items in the trash after 30 days.
        The default is false.
      '';
    };

    system.defaults.finder.FXPreferredViewStyle = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''
        Change the default finder view.
        "icnv" = Icon view, "Nlsv" = List view, "clmv" = Column View, "Flwv" = Gallery View
        The default is icnv.
      '';
    };

    system.defaults.finder.AppleShowAllExtensions = mkOption {
      type = types.nullOr types.bool;
      default = null;
      description = ''
        Whether to always show file extensions. The default is false.
      '';
    };

    system.defaults.finder.CreateDesktop = mkOption {
      type = types.nullOr types.bool;
      default = null;
      description = ''
        Whether to show icons on the desktop or not. The default is true.
      '';
    };

    system.defaults.finder.QuitMenuItem = mkOption {
      type = types.nullOr types.bool;
      default = null;
      description = ''
        Whether to allow quitting of the Finder. The default is false.
      '';
    };

    system.defaults.finder.ShowExternalHardDrivesOnDesktop = mkOption {
      type = types.nullOr types.bool;
      default = null;
      description = ''
        Whether to show external disks on desktop. The default is true.
      '';
    };

    system.defaults.finder.ShowHardDrivesOnDesktop = mkOption {
      type = types.nullOr types.bool;
      default = null;
      description = ''
        Whether to show hard disks on desktop. The default is false.
      '';
    };

    system.defaults.finder.ShowMountedServersOnDesktop = mkOption {
      type = types.nullOr types.bool;
      default = null;
      description = ''
        Whether to show connected servers on desktop. The default is false.
      '';
    };

    system.defaults.finder.ShowRemovableMediaOnDesktop = mkOption {
      type = types.nullOr types.bool;
      default = null;
      description = ''
        Whether to show removable media (CDs, DVDs and iPods) on desktop. The default is true.
      '';
    };

    system.defaults.finder._FXEnableColumnAutoSizing = mkOption {
      type = types.nullOr types.bool;
      default = null;
      description = ''
        Resize columns to fit filenames.
        The default is false.
      '';
    };

    system.defaults.finder._FXShowPosixPathInTitle = mkOption {
      type = types.nullOr types.bool;
      default = null;
      description = ''
        Whether to show the full POSIX filepath in the window title. The default is false.
      '';
    };

    system.defaults.finder._FXSortFoldersFirst = mkOption {
      type = types.nullOr types.bool;
      default = null;
      description = ''
        Keep folders on top when sorting by name. The default is false.
      '';
    };

    system.defaults.finder._FXSortFoldersFirstOnDesktop = mkOption {
      type = types.nullOr types.bool;
      default = null;
      description = ''
        Keep folders on top when sorting by name on the desktop. The default is false.
      '';
    };

    system.defaults.finder.FXEnableExtensionChangeWarning = mkOption {
      type = types.nullOr types.bool;
      default = null;
      description = ''
        Whether to show warnings when change the file extension of files. The default is true.
      '';
    };

    system.defaults.finder.NewWindowTarget = mkOption {
      type = types.nullOr (types.enum [
        "Computer"
        "OS volume"
        "Home"
        "Desktop"
        "Documents"
        "Recents"
        "iCloud Drive"
        "Other"
      ]);
      apply = key: if key == null then null else {
        "Computer" = "PfCm";
        "OS volume" = "PfVo";
        "Home" = "PfHm";
        "Desktop" = "PfDe";
        "Documents" = "PfDo";
        "Recents" = "PfAF";
        "iCloud Drive" = "PfID";
        "Other" = "PfLo";
      }.${key};
      default = null;
      description = ''
        Change the default folder shown in Finder windows. "Other" corresponds to the value of
        NewWindowTargetPath. The default is unset ("Recents").
      '';
    };

    system.defaults.finder.NewWindowTargetPath = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''
        Sets the URI to open when NewWindowTarget is "Other". Spaces and similar characters must be
        escaped. If the value is invalid, Finder will open your home directory.
        Example: "file:///Users/foo/long%20cat%20pics".
        The default is unset.
      '';
    };
  };

  config = {
    assertions = [{
      assertion = cfg.NewWindowTargetPath != null -> cfg.NewWindowTarget == "PfLo";
      message = "`system.defaults.finder.NewWindowTarget` should be set to `Other` when `NewWindowTargetPath` is non-null.";
    }
    {
      assertion = cfg.NewWindowTarget == "PfLo" -> cfg.NewWindowTargetPath != null;
      message = "`system.defaults.finder.NewWindowTargetPath` should be non-null when `NewWindowTarget` is set to `Other`.";
    }];
  };
}
