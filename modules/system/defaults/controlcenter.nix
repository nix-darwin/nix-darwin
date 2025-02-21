{ config, lib, ... }:
let
  mkEnumApply = mapping: default: v:
    if v == null then null
    else if mapping ? v then mapping.${v} else default;
  mkBoolApply = mapping: v:
    if v == null then null
    else if v then mapping.true else mapping.false;
in {
  options = {

    system.defaults.controlcenter.AccessibilityShortcuts = lib.mkOption {
      type = lib.types.nullOr (lib.types.enum [ "both" "menuBar" "controlCenter" "hide" ]);
      default = null;
      apply = mkEnumApply {
        both = 3;
        menuBar = 6;
        controlCenter = 9;
        hide = 12;
      } 12;
      description = ''
          Apple menu > System Preferences > Control Center > Accessibility Shortcuts

          Options:
            both           - Show in Menu Bar and Control Center (3)
            menuBar        - Show in Menu Bar only (6)
            controlCenter  - Show in Control Center only (1 or 9)
            hide           - Don't Show (2, 4, 8, or 12)
      '';
    };

    system.defaults.controlcenter.AirDrop = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      apply = mkBoolApply { true = 18; false = 24; };
      description = ''
          Apple menu > System Preferences > Control Center > AirDrop

          Show a AirDrop control in menu bar. Default is null.

          18 = Show in Menu Bar
          24 = Don't Show in Menu Bar
      '';
    };

    system.defaults.controlcenter.Battery = lib.mkOption {
      type = lib.types.nullOr (lib.types.enum [ "both" "menuBar" "controlCenter" "hide" ]);
      default = null;
      apply = mkEnumApply {
        both = 3;
        menuBar = 4;
        controlCenter = 9;
        hide = 12;
      } 4;
      description = ''
          Apple menu > System Preferences > Control Center > Battery

          Options:
            both           - Show in Menu Bar and Control Center (3)
            menuBar        - Show in Menu Bar only (6)
            controlCenter  - Show in Control Center only (1 or 9)
            hide           - Don't Show (2, 4, 8, or 12)
      '';
    };

    system.defaults.controlcenter.BatteryShowEnergyMode = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      description = ''
          Apple menu > System Preferences > Control Center > Battery

          Show a battery energy mode. Default is null.

          false - "When Active"
          true  - "Always"
      '';
    };

    system.defaults.controlcenter.BatteryShowPercentage = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      description = ''
          Apple menu > System Preferences > Control Center > Battery

          Show a battery percentage in menu bar. Default is null.
      '';
    };

    system.defaults.controlcenter.Bluetooth = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      apply = mkBoolApply { true = 18; false = 24; };
      description = ''
          Apple menu > System Preferences > Control Center > Bluetooth

          Show a bluetooth control in menu bar. Default is null.

          18 = Show in Menu Bar
          24 = Don't Show in Menu Bar
      '';
    };

    system.defaults.controlcenter.Display = lib.mkOption {
      type = lib.types.nullOr (lib.types.enum [ "whenActive" "hide" "always" ]);
      default = null;
      apply = mkEnumApply {
        always = 18;
        hide = 8;
        whenActive = 2;
      } 2;
      description = ''
          Apple menu > System Preferences > Control Center > Display

          Options:
            whenActive  - Show When Active (2)
            hide        - Don't Show in Menu Bar (8)
            always      - Always Show in Menu Bar (18)
      '';
    };

    system.defaults.controlcenter.FocusModes = lib.mkOption {
      type = lib.types.nullOr (lib.types.enum [ "whenActive" "hide" "always" ]);
      default = null;
      apply = mkEnumApply {
        always = 18;
        hide = 8;
        whenActive = 2;
      } 2;
      description = ''
          Apple menu > System Preferences > Control Center > Focus

          Options:
            whenActive  - Show When Active (2)
            hide        - Don't Show in Menu Bar (8)
            always      - Always Show in Menu Bar (18)
      '';
    };

    system.defaults.controlcenter.Hearing = lib.mkOption {
      type = lib.types.nullOr (lib.types.enum [ "both" "menuBar" "controlCenter" "hide" ]);
      default = null;
      apply = mkEnumApply {
        both = 3;
        menuBar = 6;
        controlCenter = 9;
        hide = 12;
      } 12;
      description = ''
          Apple menu > System Preferences > Control Center > Hearing

          Options:
            both           - Show in Menu Bar and Control Center (3)
            menuBar        - Show in Menu Bar only (6)
            controlCenter  - Show in Control Center only (1 or 9)
            hide           - Don't Show (2, 4, 8, or 12)
      '';
    };

    system.defaults.controlcenter.KeyboardBrightness = lib.mkOption {
      type = lib.types.nullOr (lib.types.enum [ "both" "menuBar" "controlCenter" "hide" ]);
      default = null;
      apply = mkEnumApply {
        both = 3;
        menuBar = 6;
        controlCenter = 9;
        hide = 12;
      } 12;
      description = ''
          Apple menu > System Preferences > Control Center > Keyboard Brightness

          Options:
            both           - Show in Menu Bar and Control Center (3)
            menuBar        - Show in Menu Bar only (6)
            controlCenter  - Show in Control Center only (1 or 9)
            hide           - Don't Show (2, 4, 8, or 12)
      '';
    };

    system.defaults.controlcenter.MusicRecognition = lib.mkOption {
      type = lib.types.nullOr (lib.types.enum [ "both" "menuBar" "controlCenter" "hide" ]);
      default = null;
      apply = mkEnumApply {
        both = 3;
        menuBar = 6;
        controlCenter = 9;
        hide = 12;
      } 12;
      description = ''
          Apple menu > System Preferences > Control Center > Music Recognition

          Options:
            both           - Show in Menu Bar and Control Center (3)
            menuBar        - Show in Menu Bar only (6)
            controlCenter  - Show in Control Center only (1 or 9)
            hide           - Don't Show (2, 4, 8, or 12)
      '';
    };

    system.defaults.controlcenter.NowPlaying = lib.mkOption {
      type = lib.types.nullOr (lib.types.enum [ "whenActive" "hide" "always" ]);
      default = null;
      apply = mkEnumApply {
        always = 18;
        hide = 8;
        whenActive = 2;
      } 2;
      description = ''
          Apple menu > System Preferences > Control Center > Now Playing

          Options:
            whenActive  - Show When Active (2)
            hide        - Don't Show in Menu Bar (8)
            always      - Always Show in Menu Bar (18)
      '';
    };

    system.defaults.controlcenter.ScreenMirroring = lib.mkOption {
      type = lib.types.nullOr (lib.types.enum [ "whenActive" "hide" "always" ]);
      default = null;
      apply = mkEnumApply {
        always = 18;
        hide = 8;
        whenActive = 2;
      } 2;
      description = ''
          Apple menu > System Preferences > Control Center > Screen Mirroring

          Options:
            whenActive  - Show When Active (2)
            hide        - Don't Show in Menu Bar (8)
            always      - Always Show in Menu Bar (18)
      '';
    };

    system.defaults.controlcenter.Sound = lib.mkOption {
      type = lib.types.nullOr (lib.types.enum [ "whenActive" "hide" "always" ]);
      default = null;
      apply = mkEnumApply {
        always = 18;
        hide = 8;
        whenActive = 2;
      } 2;
      description = ''
          Apple menu > System Preferences > Control Center > Sound

          Options:
            whenActive  - Show When Active (2)
            hide        - Don't Show in Menu Bar (8)
            always      - Always Show in Menu Bar (18)
      '';
    };

    system.defaults.controlcenter.Spotlight = lib.mkOption {
        type = lib.types.nullOr lib.types.bool;
        default = null;
        description = ''
          Apple menu > System Preferences > Control Center > Menu Bar Only > Spotlight

          Show Spotlight in menu bar. Default is null.

          false - "Don't Show in Menu Bar"
          true  - "Show in Menu Bar"
        '';
    };

    system.defaults.controlcenter.StageManager = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      apply = mkBoolApply { true = 2; false = 8; };
      description = ''
          Apple menu > System Preferences > Control Center > Stage Manager

          Show a Wi-Fi control in menu bar. Default is null.

          2 = Show in Menu Bar
          8 = Don't Show in Menu Bar
      '';
    };

    system.defaults.controlcenter.UserSwitcher = lib.mkOption {
      type = lib.types.nullOr (lib.types.enum [ "both" "menuBar" "controlCenter" "hide" ]);
      default = null;
      apply = mkEnumApply {
        both = 19;
        menuBar = 22;
        controlCenter = 25;
        hide = 28;
      } 28;
      description = ''
          Apple menu > System Preferences > Control Center > Fast User Switching

          Options:
            both           - Show in Menu Bar and Control Center (19)
            menuBar        - Show in Menu Bar (22)
            controlCenter  - Show in Control Center (25)
            hide           - Don't Show (28)
      '';
    };

    system.defaults.controlcenter.WiFi = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      apply = mkBoolApply { true = 18; false = 24; };
      description = ''
          Apple menu > System Preferences > Control Center > Wi-Fi

          Show a Wi-Fi control in menu bar. Default is null.

          18 = Show in Menu Bar
          24 = Don't Show in Menu Bar
      '';
    };

  };
}
