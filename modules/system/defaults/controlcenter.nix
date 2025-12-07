{ config, lib, ... }:
let
  mkEnumApply =
    mapping: default: v:
    if v == null then
      null
    else if builtins.isBool v then
      if v then mapping.true else mapping.false
    else if mapping ? v then
      mapping.${v}
    else
      default;
  mkBoolApply =
    mapping: v:
    if v == null then
      null
    else if v then
      mapping.true
    else
      mapping.false;
in
{
  options = {

    system.defaults.controlcenter.AccessibilityShortcuts = lib.mkOption {
      type = lib.types.nullOr (
        lib.types.enum [
          "both"
          "menuBar"
          "controlCenter"
          "hide"
        ]
      );
      default = null;
      apply = mkEnumApply {
        both = 3;
        menuBar = 6;
        controlCenter = 9;
        hide = 12;
      } 12;
      description = ''
        Show an Accessibility Shortcuts control in menu bar.

        Available settings:
          both           - Show in both the Menu Bar and Control Center (3)
          menuBar        - Show in the Menu Bar only (6)
          controlCenter  - Show in Control Center only (9)
          hide           - Don't Show (12)

        This option mirrors the setting found in:
          System Preferences > Control Center > AccessibilityShortcuts
      '';
    };

    system.defaults.controlcenter.AirDrop = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      apply = mkBoolApply {
        true = 18;
        false = 24;
      };
      description = ''
        Show an AirDrop control in menu bar.

        Available settings:
          true   - Show in Menu Bar (18)
          false  - Don't Show in Menu Bar (24)

        This option mirrors the setting found in:
          System Preferences > Control Center > AirDrop
      '';
    };

    system.defaults.controlcenter.Battery = lib.mkOption {
      type = lib.types.nullOr (
        lib.types.enum [
          "both"
          "menuBar"
          "controlCenter"
          "hide"
        ]
      );
      default = null;
      apply = mkEnumApply {
        both = 3;
        menuBar = 4;
        controlCenter = 9;
        hide = 12;
      } 4;
      description = ''
        Show a Battery control in menu bar.

        Available settings:
          both           - Show in both the Menu Bar and Control Center (3)
          menuBar        - Show in the Menu Bar only (4)
          controlCenter  - Show in Control Center only (9)
          hide           - Don't Show (12)

        This option mirrors the setting found in:
          System Preferences > Control Center > Battery
      '';
    };

    system.defaults.controlcenter.BatteryShowEnergyMode = lib.mkOption {
      type = lib.types.nullOr (
        lib.types.enum [
          "whenActive"
          "always"
        ]
      );
      default = null;
      apply = mkEnumApply {
        always = true;
        whenActive = false;
      } false;
      description = ''
        Show a Battery Energy Mode control in menu bar.

        Available settings:
          whenActive  - Show When Active
          always      - Always Show

        This option mirrors the setting found in:
          System Preferences > Control Center > Battery
      '';
    };

    system.defaults.controlcenter.BatteryShowPercentage = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      description = ''
        Show a Battery Percentage control in menu bar.

        Available settings:
          true  - Show in Menu Bar
          false - Don't Show in Menu Bar

        This option mirrors the setting found in:
          System Preferences > Control Center > Battery
      '';
    };

    system.defaults.controlcenter.Bluetooth = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      apply = mkBoolApply {
        true = 18;
        false = 24;
      };
      description = ''
        Show a Bluetooth control in menu bar.

        Available settings:
          true   - Show in Menu Bar (18)
          false  - Don't Show in Menu Bar (24)

        This option mirrors the setting found in:
          System Preferences > Control Center > Bluetooth
      '';
    };

    system.defaults.controlcenter.Display = lib.mkOption {
      type = lib.types.nullOr (
        lib.types.enum [
          "whenActive"
          "hide"
          "always"
          true
          false
        ]
      );
      default = null;
      apply = mkEnumApply {
        always = 18;
        hide = 8;
        whenActive = 2;

        true = lib.warn "system.defaults.controlcenter.Display = true is deprecated; please use \"always\" instead" 18;
        false = lib.warn "system.defaults.controlcenter.Display = false is deprecated; please use \"whenActive\" instead" 2;
      } 2;
      description = ''
        Show a Display control in menu bar.

        Available settings:
          whenActive  - Show When Active (2)
          hide        - Don't Show in Menu Bar (8)
          always      - Always Show in Menu Bar (18)

        Note: Boolean values are deprecated; please use the enum values.

        This option mirrors the setting found in:
          System Preferences > Control Center > Display
      '';
    };

    system.defaults.controlcenter.FocusModes = lib.mkOption {
      type = lib.types.nullOr (
        lib.types.enum [
          "whenActive"
          "hide"
          "always"
          true
          false
        ]
      );
      default = null;
      apply = mkEnumApply {
        always = 18;
        hide = 8;
        whenActive = 2;

        true = lib.warn "system.defaults.controlcenter.FocusModes = true is deprecated; please use \"always\" instead" 18;
        false = lib.warn "system.defaults.controlcenter.FocusModes = false is deprecated; please use \"whenActive\" instead" 2;
      } 2;
      description = ''
        Show a Focus control in menu bar.

        Available settings:
          whenActive  - Show When Active (2)
          hide        - Don't Show in Menu Bar (8)
          always      - Always Show in Menu Bar (18)

        Note: Boolean values are deprecated; please use the enum values.

        This option mirrors the setting found in:
          System Preferences > Control Center > Focus
      '';
    };

    system.defaults.controlcenter.Hearing = lib.mkOption {
      type = lib.types.nullOr (
        lib.types.enum [
          "both"
          "menuBar"
          "controlCenter"
          "hide"
        ]
      );
      default = null;
      apply = mkEnumApply {
        both = 3;
        menuBar = 6;
        controlCenter = 9;
        hide = 12;
      } 12;
      description = ''
        Show a Hearing control in menu bar.

        Available settings:
          both           - Show in both the Menu Bar and Control Center (3)
          menuBar        - Show in the Menu Bar only (6)
          controlCenter  - Show in Control Center only (9)
          hide           - Don't Show (12)

        This option mirrors the setting found in:
          System Preferences > Control Center > Hearing
      '';
    };

    system.defaults.controlcenter.KeyboardBrightness = lib.mkOption {
      type = lib.types.nullOr (
        lib.types.enum [
          "both"
          "menuBar"
          "controlCenter"
          "hide"
        ]
      );
      default = null;
      apply = mkEnumApply {
        both = 3;
        menuBar = 6;
        controlCenter = 9;
        hide = 12;
      } 12;
      description = ''
        Show a Keyboard Brightness control in menu bar.

        Available settings:
          both           - Show in both the Menu Bar and Control Center (3)
          menuBar        - Show in the Menu Bar only (6)
          controlCenter  - Show in Control Center only (9)
          hide           - Don't Show (12)

        This option mirrors the setting found in:
          System Preferences > Control Center > Keyboard Brightness
      '';
    };

    system.defaults.controlcenter.MusicRecognition = lib.mkOption {
      type = lib.types.nullOr (
        lib.types.enum [
          "both"
          "menuBar"
          "controlCenter"
          "hide"
        ]
      );
      default = null;
      apply = mkEnumApply {
        both = 3;
        menuBar = 6;
        controlCenter = 9;
        hide = 12;
      } 12;
      description = ''
        Show a Music Recognition control in menu bar.

        Available settings:
          both           - Show in both the Menu Bar and Control Center (3)
          menuBar        - Show in the Menu Bar only (6)
          controlCenter  - Show in Control Center only (9)
          hide           - Don't Show (12)

        This option mirrors the setting found in:
          System Preferences > Control Center > Music Recognition
      '';
    };

    system.defaults.controlcenter.NowPlaying = lib.mkOption {
      type = lib.types.nullOr (
        lib.types.enum [
          "whenActive"
          "hide"
          "always"
          true
          false
        ]
      );
      default = null;
      apply = mkEnumApply {
        always = 18;
        hide = 8;
        whenActive = 2;

        true = lib.warn "system.defaults.controlcenter.NowPlaying = true is deprecated; please use \"always\" instead" 18;
        false = lib.warn "system.defaults.controlcenter.NowPlaying = false is deprecated; please use \"whenActive\" instead" 2;
      } 2;
      description = ''
        Show a Now Playing control in menu bar.

        Available settings:
          whenActive  - Show When Active (2)
          hide        - Don't Show in Menu Bar (8)
          always      - Always Show in Menu Bar (18)

        Note: Boolean values are deprecated; please use the enum values.

        This option mirrors the setting found in:
          System Preferences > Control Center > Now Playing
      '';
    };

    system.defaults.controlcenter.ScreenMirroring = lib.mkOption {
      type = lib.types.nullOr (
        lib.types.enum [
          "whenActive"
          "hide"
          "always"
        ]
      );
      default = null;
      apply = mkEnumApply {
        always = 18;
        hide = 8;
        whenActive = 2;
      } 2;
      description = ''
        Show a Screen Mirroring control in menu bar.

        Available settings:
          whenActive  - Show When Active (2)
          hide        - Don't Show in Menu Bar (8)
          always      - Always Show in Menu Bar (18)

        This option mirrors the setting found in:
          System Preferences > Control Center > Screen Mirroring
      '';
    };

    system.defaults.controlcenter.Sound = lib.mkOption {
      type = lib.types.nullOr (
        lib.types.enum [
          "whenActive"
          "hide"
          "always"
          true
          false
        ]
      );
      default = null;
      apply = mkEnumApply {
        always = 18;
        hide = 8;
        whenActive = 2;

        true = lib.warn "system.defaults.controlcenter.Sound = true is deprecated; please use \"always\" instead" 18;
        false = lib.warn "system.defaults.controlcenter.Sound = false is deprecated; please use \"whenActive\" instead" 2;
      } 2;
      description = ''
        Show a Sound control in menu bar.

        Available settings:
          whenActive  - Show When Active (2)
          hide        - Don't Show in Menu Bar (8)
          always      - Always Show in Menu Bar (18)

        Note: Boolean values are deprecated; please use the enum values.

        This option mirrors the setting found in:
          System Preferences > Control Center > Sound
      '';
    };

    system.defaults.controlcenter.StageManager = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      apply = mkBoolApply {
        true = 2;
        false = 8;
      };
      description = ''
        Show a Stage Manager control in menu bar.

        Available settings:
          true   - Show in Menu Bar (2)
          false  - Don't Show in Menu Bar (8)

        This option mirrors the setting found in:
          System Preferences > Control Center > Stage Manager
      '';
    };

    system.defaults.controlcenter.UserSwitcher = lib.mkOption {
      type = lib.types.nullOr (
        lib.types.enum [
          "both"
          "menuBar"
          "controlCenter"
          "hide"
        ]
      );
      default = null;
      apply = mkEnumApply {
        both = 19;
        menuBar = 22;
        controlCenter = 25;
        hide = 28;
      } 28;
      description = ''
        Show a User Switcher control in menu bar.

        Available settings:
          both           - Show in both the Menu Bar and Control Center (19)
          menuBar        - Show in the Menu Bar only (22)
          controlCenter  - Show in Control Center only (25)
          hide           - Don't Show (28)

        This option mirrors the setting found in:
          System Preferences > Control Center > Fast User Switching
      '';
    };

    system.defaults.controlcenter.WiFi = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      apply = mkBoolApply {
        true = 18;
        false = 24;
      };
      description = ''
        Show a Wi-Fi control in menu bar.

        Available settings:
          true   - Show in Menu Bar (18)
          false  - Don't Show in Menu Bar (24)

        This option mirrors the setting found in:
          System Preferences > Control Center > Wi-Fi
      '';
    };

  };
}
