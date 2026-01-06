{ config, pkgs, lib, ... }:

{
  system.primaryUser = "test-defaults-user";

  imports = [
    {
      system.defaults.CustomUserPreferences = {
        "NSGlobalDomain" = { "TISRomanSwitchState" = 1; };
        "com.apple.Safari" = {
          "com.apple.Safari.ContentPageGroupIdentifier.WebKit2DeveloperExtrasEnabled" =
            true;
        };
      };
    }
    {
      system.defaults.CustomUserPreferences = {
        "com.apple.Safari" = {
          "NSUserKeyEquivalents"."Quit Safari" = "@^q"; # Option-Cmd-Q
        };
      };
    }
  ];

  system.defaults.NSGlobalDomain.AppleShowAllFiles = true;
  system.defaults.NSGlobalDomain.AppleEnableMouseSwipeNavigateWithScrolls = false;
  system.defaults.NSGlobalDomain.AppleEnableSwipeNavigateWithScrolls = false;
  system.defaults.NSGlobalDomain.AppleFontSmoothing = 1;
  system.defaults.NSGlobalDomain.AppleIconAppearanceTheme = "RegularDark";
  system.defaults.NSGlobalDomain.AppleICUForce24HourTime = true;
  system.defaults.NSGlobalDomain.AppleKeyboardUIMode = 3;
  system.defaults.NSGlobalDomain.ApplePressAndHoldEnabled = true;
  system.defaults.NSGlobalDomain.AppleShowAllExtensions = true;
  system.defaults.NSGlobalDomain.AppleShowScrollBars = "Always";
  system.defaults.NSGlobalDomain.AppleScrollerPagingBehavior = true;
  system.defaults.NSGlobalDomain.AppleSpacesSwitchOnActivate = false;
  system.defaults.NSGlobalDomain.NSAutomaticCapitalizationEnabled = false;
  system.defaults.NSGlobalDomain.NSAutomaticInlinePredictionEnabled = false;
  system.defaults.NSGlobalDomain.NSAutomaticDashSubstitutionEnabled = false;
  system.defaults.NSGlobalDomain.NSAutomaticPeriodSubstitutionEnabled = false;
  system.defaults.NSGlobalDomain.NSAutomaticQuoteSubstitutionEnabled = false;
  system.defaults.NSGlobalDomain.NSAutomaticSpellingCorrectionEnabled = false;
  system.defaults.NSGlobalDomain.NSAutomaticWindowAnimationsEnabled = false;
  system.defaults.NSGlobalDomain.NSDisableAutomaticTermination = true;
  system.defaults.NSGlobalDomain.NSDocumentSaveNewDocumentsToCloud = false;
  system.defaults.NSGlobalDomain.AppleWindowTabbingMode = "always";
  system.defaults.NSGlobalDomain.NSNavPanelExpandedStateForSaveMode = true;
  system.defaults.NSGlobalDomain.NSNavPanelExpandedStateForSaveMode2 = true;
  system.defaults.NSGlobalDomain.NSTableViewDefaultSizeMode = 2;
  system.defaults.NSGlobalDomain.NSTextShowsControlCharacters = true;
  system.defaults.NSGlobalDomain.NSUseAnimatedFocusRing = false;
  system.defaults.NSGlobalDomain.NSScrollAnimationEnabled = true;
  system.defaults.NSGlobalDomain.NSWindowResizeTime = 0.01;
  system.defaults.NSGlobalDomain.NSWindowShouldDragOnGesture = true;
  system.defaults.NSGlobalDomain.InitialKeyRepeat = 10;
  system.defaults.NSGlobalDomain.KeyRepeat = 1;
  system.defaults.NSGlobalDomain.PMPrintingExpandedStateForPrint = true;
  system.defaults.NSGlobalDomain.PMPrintingExpandedStateForPrint2 = true;
  system.defaults.NSGlobalDomain."com.apple.keyboard.fnState" = true;
  system.defaults.NSGlobalDomain."com.apple.mouse.tapBehavior" = 1;
  system.defaults.NSGlobalDomain."com.apple.trackpad.enableSecondaryClick" = true;
  system.defaults.NSGlobalDomain."com.apple.trackpad.trackpadCornerClickBehavior" = 1;
  system.defaults.NSGlobalDomain."com.apple.springing.enabled" = true;
  system.defaults.NSGlobalDomain."com.apple.springing.delay" = 0.0;
  system.defaults.NSGlobalDomain."com.apple.swipescrolldirection" = true;
  system.defaults.".GlobalPreferences"."com.apple.sound.beep.sound" = "/System/Library/Sounds/Funk.aiff";
  system.defaults.menuExtraClock.FlashDateSeparators = false;
  system.defaults.menuExtraClock.Show24Hour = false;
  system.defaults.menuExtraClock.ShowDayOfWeek = true;
  system.defaults.menuExtraClock.ShowDate = 2;
  system.defaults.dock.expose-group-apps = true;
  system.defaults.dock.appswitcher-all-displays = false;
  system.defaults.dock.autohide-delay = 0.24;
  system.defaults.dock.orientation = "left";
  system.defaults.dock.persistent-apps = [
    "/Applications/MyApp.app"
    { app = "/Applications/Cool.app"; }
    { spacer = { small = true; }; }
    { spacer = { small = false; }; }
    { folder = "/Applications/Utilities"; }
    { file = "/Users/example/Downloads/test.csv"; }
  ];
  system.defaults.dock.persistent-others = [
    # ./. # TODO: how to test for paths while NOT being brittle?
    "/file"
    { file = "/file"; }
    "/folder.d"
    { folder = { path = "/folder.d"; arrangement="kind"; displayas="folder"; showas = "grid"; }; }
    { folder = "/folder"; }
  ];
  system.defaults.dock.scroll-to-open = false;
  system.defaults.finder.AppleShowAllFiles = true;
  system.defaults.finder.ShowStatusBar = true;
  system.defaults.finder.ShowPathbar = true;
  system.defaults.finder.FXDefaultSearchScope = "SCcf";
  system.defaults.finder.FXPreferredViewStyle = "Flwv";
  system.defaults.finder.FXRemoveOldTrashItems = false;
  system.defaults.finder.AppleShowAllExtensions = true;
  system.defaults.finder.CreateDesktop = false;
  system.defaults.finder.NewWindowTarget = "Other";
  system.defaults.finder.NewWindowTargetPath = "file:///Library/Apple";
  system.defaults.finder.QuitMenuItem = true;
  system.defaults.finder._FXShowPosixPathInTitle = true;
  system.defaults.finder._FXSortFoldersFirst = true;
  system.defaults.finder._FXSortFoldersFirstOnDesktop = false;
  system.defaults.finder.FXEnableExtensionChangeWarning = false;
  system.defaults.finder.ShowExternalHardDrivesOnDesktop = false;
  system.defaults.finder.ShowHardDrivesOnDesktop = false;
  system.defaults.finder.ShowMountedServersOnDesktop = false;
  system.defaults.finder.ShowRemovableMediaOnDesktop = false;
  system.defaults.hitoolbox.AppleFnUsageType = "Show Emoji & Symbols";
  system.defaults.iCal."first day of week" = "Wednesday";
  system.defaults.iCal.CalendarSidebarShown = true;
  system.defaults.iCal."TimeZone support enabled" = true;
  system.defaults.screencapture.location = "/tmp";
  system.defaults.screencapture.target = "file";
  system.defaults.screencapture.include-date = true;
  system.defaults.screensaver.askForPassword = true;
  system.defaults.screensaver.askForPasswordDelay = 5;
  system.defaults.smb.NetBIOSName = "IMAC-000000";
  system.defaults.smb.ServerDescription = ''Darwin\\U2019's iMac'';
  system.defaults.universalaccess.mouseDriverCursorSize = 1.5;
  system.defaults.universalaccess.reduceMotion = true;
  system.defaults.universalaccess.reduceTransparency = true;
  system.defaults.universalaccess.closeViewScrollWheelToggle = true;
  system.defaults.universalaccess.closeViewZoomFollowsFocus = true;
  system.defaults.ActivityMonitor.ShowCategory = 103;
  system.defaults.ActivityMonitor.IconType = 3;
  system.defaults.ActivityMonitor.SortColumn = "CPUUsage";
  system.defaults.ActivityMonitor.SortDirection = 0;
  system.defaults.ActivityMonitor.OpenMainWindow = true;
  system.defaults.WindowManager.GloballyEnabled = false;
  system.defaults.WindowManager.EnableStandardClickToShowDesktop = false;
  system.defaults.WindowManager.AutoHide = false;
  system.defaults.WindowManager.AppWindowGroupingBehavior = true;
  system.defaults.WindowManager.StandardHideDesktopIcons = false;
  system.defaults.WindowManager.HideDesktop = false;
  system.defaults.WindowManager.EnableTilingByEdgeDrag = true;
  system.defaults.WindowManager.EnableTopTilingByEdgeDrag = true;
  system.defaults.WindowManager.EnableTilingOptionAccelerator = true;
  system.defaults.WindowManager.EnableTiledWindowMargins = true;
  system.defaults.WindowManager.StandardHideWidgets = true;
  system.defaults.WindowManager.StageManagerHideWidgets = true;
  system.defaults.controlcenter.BatteryShowPercentage = true;
  system.defaults.controlcenter.Sound = false;
  system.defaults.controlcenter.Bluetooth = true;
  system.defaults.controlcenter.AirDrop = true;
  system.defaults.controlcenter.Display = false;
  system.defaults.controlcenter.FocusModes = false;
  system.defaults.controlcenter.NowPlaying = true;
  test = lib.strings.concatMapStringsSep "\n"
    (x: ''
      echo >&2 "checking ${x} defaults write in /activate"
      ${pkgs.python3}/bin/python3 <<EOL
      import sys
      from pathlib import Path
      fixture = '${./fixtures/system-defaults-write}/${x}.txt'
      out = '${config.out}/activate'
      if Path(fixture).read_text() not in Path(out).read_text():
        print("Did not find content from %s in %s" % (fixture, out), file=sys.stderr)
        sys.exit(1)
      EOL
    '') [
    "system"
    "user"
  ];
}
