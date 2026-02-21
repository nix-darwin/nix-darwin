{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.system.keyboard;
in

{
  options = {
    system.keyboard.enableKeyMapping = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to enable keyboard mappings.";
    };

    system.keyboard.remapCapsLockToControl = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to remap the Caps Lock key to Control.";
    };

    system.keyboard.remapCapsLockToEscape = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to remap the Caps Lock key to Escape.";
    };

    system.keyboard.nonUS.remapTilde = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to remap the Tilde key on non-us keyboards.";
    };

    system.keyboard.swapLeftCommandAndLeftAlt = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to swap the left Command key and left Alt key.";
    };

    system.keyboard.swapRightCommandAndRightOption = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to swap the right Command key and right Option key.";
    };

    system.keyboard.swapCapsLockAndEscape = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to swap the Caps Lock key and Escape key.";
    };

    system.keyboard.swapLeftCtrlAndFn = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to swap the left Control key and Fn (Globe) key.";
    };

    system.keyboard.userKeyMapping = mkOption {
      internal = true;
      type = types.listOf (types.attrsOf types.int);
      default = [];
      description = ''
        List of keyboard mappings to apply, for more information see
        <https://developer.apple.com/library/content/technotes/tn2450/_index.html>.
      '';
    };
  };

  config = {

    warnings = mkIf (!cfg.enableKeyMapping && cfg.userKeyMapping != [])
      [ "system.keyboard.enableKeyMapping is not enabled, keyboard mappings will not be configured." ];

    system.keyboard.userKeyMapping = [
      (mkIf cfg.remapCapsLockToControl { HIDKeyboardModifierMappingSrc = 30064771129; HIDKeyboardModifierMappingDst = 30064771296; })
      (mkIf cfg.remapCapsLockToEscape { HIDKeyboardModifierMappingSrc = 30064771129; HIDKeyboardModifierMappingDst = 30064771113; })
      (mkIf cfg.nonUS.remapTilde { HIDKeyboardModifierMappingSrc = 30064771172; HIDKeyboardModifierMappingDst = 30064771125; })
      (mkIf cfg.swapCapsLockAndEscape {
        HIDKeyboardModifierMappingSrc = 30064771129;
        HIDKeyboardModifierMappingDst = 30064771113;
      })
      (mkIf cfg.swapCapsLockAndEscape {
        HIDKeyboardModifierMappingSrc = 30064771113;
        HIDKeyboardModifierMappingDst = 30064771129;
      })
      (mkIf cfg.swapLeftCommandAndLeftAlt {
        HIDKeyboardModifierMappingSrc = 30064771299;
        HIDKeyboardModifierMappingDst = 30064771298;
      })
      (mkIf cfg.swapLeftCommandAndLeftAlt {
        HIDKeyboardModifierMappingSrc = 30064771298;
        HIDKeyboardModifierMappingDst = 30064771299;
      })
      (mkIf cfg.swapRightCommandAndRightOption {
        HIDKeyboardModifierMappingSrc = 30064771303;
        HIDKeyboardModifierMappingDst = 30064771302;
      })
      (mkIf cfg.swapRightCommandAndRightOption {
        HIDKeyboardModifierMappingSrc = 30064771302;
        HIDKeyboardModifierMappingDst = 30064771303;
      })
      (mkIf cfg.swapLeftCtrlAndFn {
        HIDKeyboardModifierMappingSrc = 30064771296;
        HIDKeyboardModifierMappingDst = 1095216660483;
      })
      (mkIf cfg.swapLeftCtrlAndFn {
        HIDKeyboardModifierMappingSrc = 1095216660483;
        HIDKeyboardModifierMappingDst = 30064771296;
      })
    ];

    system.activationScripts.keyboard.text = optionalString cfg.enableKeyMapping ''
      # Configuring keyboard
      echo "configuring keyboard..." >&2
      hidutil property --set '{"UserKeyMapping":${builtins.toJSON cfg.userKeyMapping}}' > /dev/null
    '';

  };
}
