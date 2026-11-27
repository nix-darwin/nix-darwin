{
  config,
  extendModules,
  lib,
  pkgs,
  ...
}:

let
  optionPath = [
    "system"
    "keyboard"
    "shortcuts"
    "missionControl"
    "switchToDesktop"
  ];
  withShortcuts =
    shortcuts:
    (extendModules {
      modules = [ (lib.setAttrByPath optionPath (lib.mkForce shortcuts)) ];
    }).config;
  valid = {
    "1" = {
      key = "1";
      mods = [ "option" ];
    };
  };
  accepts =
    shortcuts:
    (builtins.tryEval (
      builtins.deepSeq (lib.getAttrFromPath optionPath (withShortcuts shortcuts)) true
    )).success;
  hasFailedAssertion = otherConfig: lib.any (assertion: !assertion.assertion) otherConfig.assertions;
  withoutShortcuts = withShortcuts { };
  withoutUser =
    (extendModules {
      modules = [ { system.primaryUser = lib.mkForce null; } ];
    }).config;
in
{
  system.primaryUser = "test-shortcuts-user";

  # Exercise merging a shortcut across modules.
  imports = [
    { system.keyboard.shortcuts.missionControl.switchToDesktop."4".key = "4"; }
    { system.keyboard.shortcuts.missionControl.switchToDesktop."4".mods = [ "option" ]; }
  ];

  system.keyboard.shortcuts.missionControl.switchToDesktop = {
    "1" = {
      key = "1";
      mods = [ "option" ];
    };
    "2".enabled = false;
    "9" = {
      key = "9";
      mods = [
        "control"
        "option"
      ];
    };
    "10" = {
      key = "F10";
      mods = [ "command" ];
    };
    "16" = {
      key = "RightArrow";
      mods = [
        "shift"
        "control"
        "option"
        "command"
        "fn"
      ];
    };
  };

  test =
    assert !hasFailedAssertion config;
    assert accepts valid;
    assert hasFailedAssertion (withShortcuts {
      "0" = {
        key = "1";
      };
    });
    assert hasFailedAssertion (withShortcuts {
      "17" = {
        key = "1";
      };
    });
    assert hasFailedAssertion (withShortcuts {
      "01" = {
        key = "1";
      };
    });
    assert hasFailedAssertion (withShortcuts {
      "desktop" = {
        key = "1";
      };
    });
    assert
      !accepts {
        "1" = {
          key = "not-a-key";
        };
      };
    assert
      !accepts {
        "1" = {
          key = "1";
          mods = [ "not-a-modifier" ];
        };
      };
    assert hasFailedAssertion (withShortcuts {
      "1" = { };
    });
    assert hasFailedAssertion (withShortcuts {
      "1" = {
        key = "1";
        mods = [
          "option"
          "option"
        ];
      };
    });
    assert hasFailedAssertion withoutUser;
    assert
      !lib.hasInfix "com.apple.symbolichotkeys" withoutShortcuts.system.activationScripts.userDefaults.text;
    assert
      !builtins.elem "system.keyboard.shortcuts.missionControl.switchToDesktop" withoutShortcuts.system.requiresPrimaryUser;
    ''
      ${lib.getExe pkgs.python3} ${./system-keyboard-shortcuts.py} \
        ${pkgs.writeText "mission-control-shortcuts.sh" config.system.activationScripts.userDefaults.text}
      grep -F 'com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add' ${config.out}/activate
    '';
}
