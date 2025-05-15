{ config, lib, ... }:

with lib;

let
  cfg = config.system.defaults;

  writeDefault = domain: key: value:
    "defaults write ${domain} '${key}' $'${strings.escape [ "'" ] (generators.toPlist { } value)}'";

  defaultsToList = domain: attrs: mapAttrsToList (writeDefault domain) (filterAttrs (n: v: v != null) attrs);
  # Filter out options to not pass through
  # dock has alias options that we need to ignore
  dockFiltered = (builtins.removeAttrs cfg.dock ["expose-group-by-app"]);

  # defaults
  alf = defaultsToList "/Library/Preferences/com.apple.alf" cfg.alf;
  loginwindow = defaultsToList "/Library/Preferences/com.apple.loginwindow" cfg.loginwindow;
  smb = defaultsToList "/Library/Preferences/SystemConfiguration/com.apple.smb.server" cfg.smb;
  SoftwareUpdate = defaultsToList "/Library/Preferences/com.apple.SoftwareUpdate" cfg.SoftwareUpdate;

  # userDefaults
  GlobalPreferences = defaultsToList ".GlobalPreferences" cfg.".GlobalPreferences";
  LaunchServices = defaultsToList "com.apple.LaunchServices" cfg.LaunchServices;
  NSGlobalDomain = defaultsToList "-g" cfg.NSGlobalDomain;
  menuExtraClock = defaultsToList "com.apple.menuextra.clock" cfg.menuExtraClock;
  dock = defaultsToList "com.apple.dock" dockFiltered;
  finder = defaultsToList "com.apple.finder" cfg.finder;
  hitoolbox = defaultsToList "com.apple.HIToolbox" cfg.hitoolbox;
  magicmouse = defaultsToList "com.apple.AppleMultitouchMouse" cfg.magicmouse;
  magicmouseBluetooth = defaultsToList "com.apple.driver.AppleMultitouchMouse.mouse" cfg.magicmouse;
  screencapture = defaultsToList "com.apple.screencapture" cfg.screencapture;
  screensaver = defaultsToList "com.apple.screensaver" cfg.screensaver;
  spaces = defaultsToList "com.apple.spaces" cfg.spaces;
  trackpad = defaultsToList "com.apple.AppleMultitouchTrackpad" cfg.trackpad;
  trackpadBluetooth = defaultsToList "com.apple.driver.AppleBluetoothMultitouch.trackpad" cfg.trackpad;
  universalaccess = defaultsToList "com.apple.universalaccess" cfg.universalaccess;
  ActivityMonitor = defaultsToList "com.apple.ActivityMonitor" cfg.ActivityMonitor;
  WindowManager = defaultsToList "com.apple.WindowManager" cfg.WindowManager;
  controlcenter = defaultsToList "~/Library/Preferences/ByHost/com.apple.controlcenter" cfg.controlcenter;  
  Spotlight = defaultsToList "~/Library/Preferences/ByHost/com.apple.Spotlight" cfg.Spotlight;  
  CustomUserPreferences = flatten (mapAttrsToList (name: value: defaultsToList name value) cfg.CustomUserPreferences);
  CustomSystemPreferences = flatten (mapAttrsToList (name: value: defaultsToList name value) cfg.CustomSystemPreferences);


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

    system.activationScripts.defaults.text = mkIfLists [
      alf
      loginwindow
      smb
      SoftwareUpdate
      CustomSystemPreferences
    ]
      ''
        # Set defaults
        echo >&2 "system defaults..."
        ${concatStringsSep "\n" alf}
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
        Spotlight
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
        ${concatStringsSep "\n" Spotlight}

        ${optionalString (length dock > 0) ''
          # Only restart Dock if current user is logged in
          if pgrep -xu $UID Dock >/dev/null; then
            echo >&2 "restarting Dock..."
            killall Dock || true
          fi
        ''}
      '';

  };
}
