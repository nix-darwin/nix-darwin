{ config, lib, ... }:
let
  # Maps string values to macOS integers
  mkApply =
    mapping: default: v:
    if v == null then null else mapping.${v} or default;

  # Like mkApply but with deprecation warnings for boolean values
  mkApplyWithBoolWarn =
    mapping: boolMap: default: v:
    if v == null then
      null
    else if v == true then
      lib.warn boolMap.trueWarn (mapping.${boolMap.trueVal})
    else if v == false then
      lib.warn boolMap.falseWarn (mapping.${boolMap.falseVal})
    else
      mapping.${v} or default;

  # "show" | "hide" (with deprecated bool)
  visibilityType = lib.types.enum [
    "show"
    "hide"
    true
    false
  ];
  visibilityApply =
    mkApplyWithBoolWarn
      {
        show = 18;
        hide = 24;
      }
      {
        trueWarn = "Boolean values are deprecated; use \"show\" instead";
        trueVal = "show";
        falseWarn = "Boolean values are deprecated; use \"hide\" instead";
        falseVal = "hide";
      }
      18;

  # "whenActive" | "always" | "hide" (with deprecated bool)
  activeType = lib.types.enum [
    "whenActive"
    "always"
    "hide"
    true
    false
  ];
  activeApply =
    mkApplyWithBoolWarn
      {
        whenActive = 2;
        always = 18;
        hide = 8;
      }
      {
        trueWarn = "Boolean values are deprecated; use \"always\" instead";
        trueVal = "always";
        falseWarn = "Boolean values are deprecated; use \"whenActive\" instead";
        falseVal = "whenActive";
      }
      2;

  # "both" | "menuBar" | "controlCenter" | "hide"
  placementType = lib.types.enum [
    "both"
    "menuBar"
    "controlCenter"
    "hide"
  ];
  placementApply = mkApply {
    both = 3;
    menuBar = 6;
    controlCenter = 9;
    hide = 12;
  } 12;

  mkOpt =
    {
      type,
      apply ? null,
      description,
    }:
    lib.mkOption {
      type = lib.types.nullOr type;
      default = null;
      inherit description;
    }
    // lib.optionalAttrs (apply != null) { inherit apply; };
in
{
  options.system.defaults.controlcenter = {

    AccessibilityShortcuts = mkOpt {
      type = placementType;
      apply = placementApply;
      description = ''
        Show Accessibility Shortcuts in Menu Bar and/or Control Center.
        Options: "both", "menuBar", "controlCenter", "hide"

        Corresponds to: System Settings > Control Center > Accessibility Shortcuts
      '';
    };

    AirDrop = mkOpt {
      type = visibilityType;
      apply = visibilityApply;
      description = ''
        Show AirDrop in Menu Bar.
        Options: "show", "hide"

        Corresponds to: System Settings > Control Center > AirDrop
      '';
    };

    Battery = mkOpt {
      type = placementType;
      apply = mkApply {
        both = 3;
        menuBar = 4;
        controlCenter = 9;
        hide = 12;
      } 4;
      description = ''
        Show Battery in Menu Bar and/or Control Center.
        Options: "both", "menuBar", "controlCenter", "hide"

        Corresponds to: System Settings > Control Center > Battery
      '';
    };

    BatteryShowEnergyMode = mkOpt {
      type = lib.types.enum [
        "whenActive"
        "always"
      ];
      apply = mkApply {
        always = true;
        whenActive = false;
      } false;
      description = ''
        Show battery energy mode indicator.
        Options: "whenActive", "always"

        Corresponds to: System Settings > Control Center > Battery > Show Energy Mode
      '';
    };

    BatteryShowPercentage = mkOpt {
      type = lib.types.bool;
      description = ''
        Show battery percentage in Menu Bar.

        Corresponds to: System Settings > Control Center > Battery > Show Percentage
      '';
    };

    Bluetooth = mkOpt {
      type = visibilityType;
      apply = visibilityApply;
      description = ''
        Show Bluetooth in Menu Bar.
        Options: "show", "hide"

        Corresponds to: System Settings > Control Center > Bluetooth
      '';
    };

    Display = mkOpt {
      type = activeType;
      apply = activeApply;
      description = ''
        Show Display in Menu Bar.
        Options: "whenActive", "always", "hide"

        Corresponds to: System Settings > Control Center > Display
      '';
    };

    FocusModes = mkOpt {
      type = activeType;
      apply = activeApply;
      description = ''
        Show Focus in Menu Bar.
        Options: "whenActive", "always", "hide"

        Corresponds to: System Settings > Control Center > Focus
      '';
    };

    Hearing = mkOpt {
      type = placementType;
      apply = placementApply;
      description = ''
        Show Hearing in Menu Bar and/or Control Center.
        Options: "both", "menuBar", "controlCenter", "hide"

        Corresponds to: System Settings > Control Center > Hearing
      '';
    };

    KeyboardBrightness = mkOpt {
      type = placementType;
      apply = placementApply;
      description = ''
        Show Keyboard Brightness in Menu Bar and/or Control Center.
        Options: "both", "menuBar", "controlCenter", "hide"

        Corresponds to: System Settings > Control Center > Keyboard Brightness
      '';
    };

    MusicRecognition = mkOpt {
      type = placementType;
      apply = placementApply;
      description = ''
        Show Music Recognition in Menu Bar and/or Control Center.
        Options: "both", "menuBar", "controlCenter", "hide"

        Corresponds to: System Settings > Control Center > Music Recognition
      '';
    };

    NowPlaying = mkOpt {
      type = activeType;
      apply = activeApply;
      description = ''
        Show Now Playing in Menu Bar.
        Options: "whenActive", "always", "hide"

        Corresponds to: System Settings > Control Center > Now Playing
      '';
    };

    ScreenMirroring = mkOpt {
      type = lib.types.enum [
        "whenActive"
        "always"
        "hide"
      ];
      apply = activeApply;
      description = ''
        Show Screen Mirroring in Menu Bar.
        Options: "whenActive", "always", "hide"

        Corresponds to: System Settings > Control Center > Screen Mirroring
      '';
    };

    Sound = mkOpt {
      type = activeType;
      apply = activeApply;
      description = ''
        Show Sound in Menu Bar.
        Options: "whenActive", "always", "hide"

        Corresponds to: System Settings > Control Center > Sound
      '';
    };

    StageManager = mkOpt {
      type = lib.types.enum [
        "whenActive"
        "hide"
        true
        false
      ];
      apply =
        mkApplyWithBoolWarn
          {
            whenActive = 2;
            hide = 8;
          }
          {
            trueWarn = "Boolean values are deprecated; use \"whenActive\" instead";
            trueVal = "whenActive";
            falseWarn = "Boolean values are deprecated; use \"hide\" instead";
            falseVal = "hide";
          }
          2;
      description = ''
        Show Stage Manager in Menu Bar.
        Options: "whenActive", "hide"

        Corresponds to: System Settings > Control Center > Stage Manager
      '';
    };

    UserSwitcher = mkOpt {
      type = placementType;
      apply = mkApply {
        both = 19;
        menuBar = 22;
        controlCenter = 25;
        hide = 28;
      } 28;
      description = ''
        Show Fast User Switching in Menu Bar and/or Control Center.
        Options: "both", "menuBar", "controlCenter", "hide"

        Corresponds to: System Settings > Control Center > Fast User Switching
      '';
    };

    WiFi = mkOpt {
      type = visibilityType;
      apply = visibilityApply;
      description = ''
        Show Wi-Fi in Menu Bar.
        Options: "show", "hide"

        Corresponds to: System Settings > Control Center > Wi-Fi
      '';
    };

  };
}
