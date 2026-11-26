{ config, lib, ... }:

let
  cfg = config.system.keyboard.shortcuts.missionControl.switchToDesktop;
  optionName = "system.keyboard.shortcuts.missionControl.switchToDesktop";
  desktopNumbers = map toString (lib.range 1 16);

  # Apple virtual key codes from HIToolbox/Events.h. Names refer to physical
  # ANSI key positions, rather than characters produced by a keyboard layout.
  keyCodes = {
    a = 0;
    s = 1;
    d = 2;
    f = 3;
    h = 4;
    g = 5;
    z = 6;
    x = 7;
    c = 8;
    v = 9;
    b = 11;
    q = 12;
    w = 13;
    e = 14;
    r = 15;
    y = 16;
    t = 17;
    "1" = 18;
    "2" = 19;
    "3" = 20;
    "4" = 21;
    "6" = 22;
    "5" = 23;
    "=" = 24;
    "9" = 25;
    "7" = 26;
    "-" = 27;
    "8" = 28;
    "0" = 29;
    "]" = 30;
    o = 31;
    u = 32;
    "[" = 33;
    i = 34;
    p = 35;
    l = 37;
    j = 38;
    "'" = 39;
    k = 40;
    ";" = 41;
    "\\" = 42;
    "," = 43;
    "/" = 44;
    n = 45;
    m = 46;
    "." = 47;
    "`" = 50;
    Return = 36;
    Tab = 48;
    Space = 49;
    Delete = 51;
    Escape = 53;
    Home = 115;
    PageUp = 116;
    ForwardDelete = 117;
    End = 119;
    PageDown = 121;
    LeftArrow = 123;
    RightArrow = 124;
    DownArrow = 125;
    UpArrow = 126;
  }
  // builtins.listToAttrs (
    lib.imap0
      (index: code: {
        name = "F${toString (index + 1)}";
        value = code;
      })
      [
        122
        120
        99
        118
        96
        97
        98
        100
        101
        109
        103
        111
        105
        107
        113
        106
        64
        79
        80
        90
      ]
  );

  modifierMasks = {
    shift = 131072;
    control = 262144;
    option = 524288;
    command = 1048576;
    fn = 8388608;
  };

  shortcutType = lib.types.submodule {
    options = {
      enabled = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to enable the shortcut for this desktop.";
      };
      key = lib.mkOption {
        type = lib.types.nullOr (lib.types.enum (builtins.attrNames keyCodes));
        default = null;
        example = "4";
        description = ''
          Physical key for this shortcut. Letter and punctuation names use
          ANSI key positions. Must be set when the shortcut is enabled.
        '';
      };
      mods = lib.mkOption {
        type = lib.types.listOf (lib.types.enum (builtins.attrNames modifierMasks));
        default = [ ];
        example = [ "option" ];
        description = "Modifier keys for this shortcut, without duplicates.";
      };
    };
  };

  user = lib.escapeShellArg config.system.primaryUser;
  asUser = ''launchctl asuser "$(id -u -- ${user})" sudo --user=${user} --'';
  writeShortcut =
    desktop: shortcut:
    let
      # IDs 118 through 133 are the native Switch to Desktop 1 through 16
      # actions, listed in KeyboardSettings.appex/DefaultSpacesShortcuts.xml.
      id = toString (117 + lib.toInt desktop);
      value = {
        enabled = shortcut.enabled;
      }
      // lib.optionalAttrs (shortcut.key != null) {
        value = {
          type = "standard";
          parameters = [
            65535
            keyCodes.${shortcut.key}
            (lib.foldl' (mask: modifier: mask + modifierMasks.${modifier}) 0 (lib.unique shortcut.mods))
          ];
        };
      };
      plist = lib.generators.toPlist { escape = true; } value;
    in
    "${asUser} defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add ${id} ${lib.escapeShellArg plist}";
in
{
  meta.maintainers = [ lib.maintainers.NikoPit or "NikoPit" ];

  options.system.keyboard.shortcuts.missionControl.switchToDesktop = lib.mkOption {
    type = lib.types.attrsOf shortcutType;
    default = { };
    example = {
      "1" = {
        key = "1";
        mods = [ "option" ];
      };
      "4" = {
        key = "4";
        mods = [ "option" ];
      };
      "9" = {
        enabled = false;
      };
    };
    description = ''
      Native Mission Control shortcuts for switching to numbered desktops,
      applied to {option}`system.primaryUser`. Attribute names must be desktop
      numbers from "1" through "16". The desktops must already exist.

      Only listed shortcuts are written; other system shortcuts are preserved.
      Removing an entry leaves its last setting in place. Set `enabled`
      to false to disable a shortcut explicitly. Log out and back in after
      applying changes so macOS reloads the shortcuts.

      This does not create desktops or change animation and desktop ordering
      preferences. A hotkey daemon must not intercept the same key combination.
    '';
  };

  config = lib.mkIf (cfg != { }) {
    assertions = [
      {
        assertion = lib.all (desktop: builtins.elem desktop desktopNumbers) (builtins.attrNames cfg);
        message = "${optionName} attribute names must be desktop numbers from \"1\" through \"16\".";
      }
    ]
    ++ lib.concatLists (
      lib.mapAttrsToList (desktop: shortcut: [
        {
          assertion = !shortcut.enabled || shortcut.key != null;
          message = "${optionName}.\"${desktop}\".key must be set when the shortcut is enabled.";
        }
        {
          assertion = builtins.length shortcut.mods == builtins.length (lib.unique shortcut.mods);
          message = "${optionName}.\"${desktop}\".mods must not contain duplicate modifiers.";
        }
      ]) cfg
    );

    system.requiresPrimaryUser = [ optionName ];

    system.activationScripts.userDefaults.text = lib.mkAfter ''
      # Configure only the requested Mission Control desktop shortcuts.
      ${lib.concatStringsSep "\n" (lib.mapAttrsToList writeShortcut cfg)}
    '';
  };
}
