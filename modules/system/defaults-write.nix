{ config, lib, ... }:

with lib;

let
  cfg = config.system.defaults;

  writeDefault = domain: key: value:
    "defaults write ${domain} ${escapeShellArg key} ${escapeShellArg (generators.toPlist { escape = true; } value)}";

  defaultsToList = domain: attrs: mapAttrsToList (writeDefault domain) (filterAttrs (n: v: v != null) attrs);
  userDefaultsToList = domain: attrs: let
    user = escapeShellArg config.system.primaryUser;
  in map
    (cmd: ''launchctl asuser "$(id -u -- ${user})" sudo --user=${user} -- ${cmd}'')
    (defaultsToList domain attrs);

  # Filter out options to not pass through
  # dock has alias options that we need to ignore
  dockFiltered = (builtins.removeAttrs cfg.dock ["expose-group-by-app"]);

  # defaults
  loginwindow = defaultsToList "/Library/Preferences/com.apple.loginwindow" cfg.loginwindow;
  smb = defaultsToList "/Library/Preferences/SystemConfiguration/com.apple.smb.server" cfg.smb;
  SoftwareUpdate = defaultsToList "/Library/Preferences/com.apple.SoftwareUpdate" cfg.SoftwareUpdate;
  CustomSystemPreferences = flatten (mapAttrsToList (name: value: defaultsToList name value) cfg.CustomSystemPreferences);

  # userDefaults
  GlobalPreferences = userDefaultsToList ".GlobalPreferences" cfg.".GlobalPreferences";
  LaunchServices = userDefaultsToList "com.apple.LaunchServices" cfg.LaunchServices;
  NSGlobalDomain = userDefaultsToList "-g" cfg.NSGlobalDomain;
  menuExtraClock = userDefaultsToList "com.apple.menuextra.clock" cfg.menuExtraClock;
  dock = userDefaultsToList "com.apple.dock" dockFiltered;
  finder = userDefaultsToList "com.apple.finder" cfg.finder;
  hitoolbox = userDefaultsToList "com.apple.HIToolbox" cfg.hitoolbox;
  iCal = userDefaultsToList "com.apple.iCal" cfg.iCal;
  magicmouse = userDefaultsToList "com.apple.AppleMultitouchMouse" cfg.magicmouse;
  magicmouseBluetooth = userDefaultsToList "com.apple.driver.AppleMultitouchMouse.mouse" cfg.magicmouse;
  screencapture = userDefaultsToList "com.apple.screencapture" cfg.screencapture;
  screensaver = userDefaultsToList "com.apple.screensaver" cfg.screensaver;
  spaces = userDefaultsToList "com.apple.spaces" cfg.spaces;
  trackpad = userDefaultsToList "com.apple.AppleMultitouchTrackpad" cfg.trackpad;
  trackpadBluetooth = userDefaultsToList "com.apple.driver.AppleBluetoothMultitouch.trackpad" cfg.trackpad;
  universalaccess = userDefaultsToList "com.apple.universalaccess" cfg.universalaccess;
  ActivityMonitor = userDefaultsToList "com.apple.ActivityMonitor" cfg.ActivityMonitor;
  WindowManager = userDefaultsToList "com.apple.WindowManager" cfg.WindowManager;
  controlcenter = userDefaultsToList "~${config.system.primaryUser}/Library/Preferences/ByHost/com.apple.controlcenter" cfg.controlcenter;
  CustomUserPreferences = flatten (mapAttrsToList (name: value: userDefaultsToList name value) cfg.CustomUserPreferences);


  mkIfLists = list: mkIf (any (attrs: attrs != [ ]) list);
in

{
  config = {

    # Type used for `system.defaults.<domain>.*` options that previously accepted float values as a
    # string.
    lib.defaults.types.floatWithDeprecationError = types.float // {
      check = x:
        if isString x && builtins.match "^[+-]?([0-9]*[.])?[0-9]+$" x != null
        then throw "Using strings for `system.defaults.<domain>.*' options of type float is no longer permitted, use native float values instead."
        else types.float.check x;
    };

    system.requiresPrimaryUser = concatMap
      (scope: mapAttrsToList
        (name: value: mkIf (value != null) (showOption [ "system" "defaults" scope name ]))
        (if scope == "dock" then dockFiltered else cfg.${scope}))
      [
        "CustomUserPreferences"
        ".GlobalPreferences"
        "LaunchServices"
        "NSGlobalDomain"
        "menuExtraClock"
        "dock"
        "finder"
        "hitoolbox"
        "magicmouse"
        "screencapture"
        "screensaver"
        "spaces"
        "trackpad"
        "universalaccess"
        "ActivityMonitor"
        "WindowManager"
        "controlcenter"
      ];

    system.activationScripts.defaults.text = mkIfLists [
      loginwindow
      smb
      SoftwareUpdate
      CustomSystemPreferences
    ]
      ''
        # Set defaults
        echo >&2 "system defaults..."
        ${concatStringsSep "\n" loginwindow}
        ${concatStringsSep "\n" smb}
        ${concatStringsSep "\n" SoftwareUpdate}
        ${concatStringsSep "\n" CustomSystemPreferences}
      '';

    system.activationScripts.userDefaults.text = mkIfLists
      [
        GlobalPreferences
        LaunchServices
        NSGlobalDomain
        menuExtraClock
        dock
        finder
        hitoolbox
        iCal
        magicmouse
        magicmouseBluetooth
        screencapture
        screensaver
        spaces
        trackpad
        trackpadBluetooth
        universalaccess
        ActivityMonitor
        CustomUserPreferences
        WindowManager
        controlcenter
      ]
      ''
        # Set defaults
        echo >&2 "user defaults..."

        ${concatStringsSep "\n" NSGlobalDomain}

        ${concatStringsSep "\n" GlobalPreferences}
        ${concatStringsSep "\n" LaunchServices}
        ${concatStringsSep "\n" menuExtraClock}
        ${concatStringsSep "\n" dock}
        ${concatStringsSep "\n" finder}
        ${concatStringsSep "\n" hitoolbox}
        ${concatStringsSep "\n" iCal}
        ${concatStringsSep "\n" magicmouse}
        ${concatStringsSep "\n" magicmouseBluetooth}
        ${concatStringsSep "\n" screencapture}
        ${concatStringsSep "\n" screensaver}
        ${concatStringsSep "\n" spaces}
        ${concatStringsSep "\n" trackpad}
        ${concatStringsSep "\n" trackpadBluetooth}
        ${concatStringsSep "\n" universalaccess}
        ${concatStringsSep "\n" ActivityMonitor}
        ${concatStringsSep "\n" CustomUserPreferences}
        ${concatStringsSep "\n" WindowManager}
        ${concatStringsSep "\n" controlcenter}

        ${optionalString (length dock > 0) ''
          echo >&2 "restarting Dock..."
          killall -qu ${escapeShellArg config.system.primaryUser} Dock || true
        ''}
      '';

  };
}
