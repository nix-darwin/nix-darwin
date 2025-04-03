#
# When this module is enabled it will override system shortcuts,
# but only those that it knows about. Defaults are the same as in system.
#
# Only some of the shortcuts have been implemented. Please, add more!
#
# To add a new shortcut, you need to know:
#
# * its numeric id,
# * default value (enabled or not and the key combo).
#
# The shorcuts are stored in `~/Library/Preferences/com.apple.symbolichotkeys.plist`.
# This file is a binary plist, so the first thing you need to do is
# convert it to XML:
#
# * plutil -convert xml1 ~/Library/Preferences/com.apple.symbolichotkeys.plist
#
# Now copy this file somewhere.
#
# Next go to System Preferences → Keyboard → Shortcuts, find the shortcut you
# are interested in, change something in it. Convert the file above to XML again
# and diff with the saved copy. The `key` of the changed entry is the numeric id
# of the shortcut. Press “Restore Defaults” in preferences to find out the default
# key combo.
#
# After you are done, copy your saved plist back and re-login just in case.
#

{ config, lib, pkgs, ... }:

let
  inherit (lib) attrsets lists options types;

  cfg = config.system.keyboard.shortcuts;

  modNames = attrsets.genAttrs ["shift" "control" "option" "command"] (x: x);

  # NOTE:
  # What comes below does not seem to be documented, so these are merely
  # reverse-engineered guesses.

  # /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/System/Library/Frameworks/IOKit.framework/Headers/hidsystem/IOLLEvent.h
  modMasks = {
    shift   = 131072;  # 0x00020000
    control = 262144;  # 0x00040000
    option  = 524288;  # 0x00080000
    command = 1048576; # 0x00100000
  };

  # /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/System/Library/Frameworks/Carbon.framework/Frameworks/HIToolbox.framework/Headers/Events.h
  keyCodes = {
    "A"  = 0;  # 0x00
    "S"  = 1;  # 0x01
    "D"  = 2;  # 0x02
    "F"  = 3;  # 0x03
    "H"  = 4;  # 0x04
    "G"  = 5;  # 0x05
    "Z"  = 6;  # 0x06
    "X"  = 7;  # 0x07
    "C"  = 8;  # 0x08
    "V"  = 9;  # 0x09
    "B"  = 11; # 0x0B
    "Q"  = 12; # 0x0C
    "W"  = 13; # 0x0D
    "E"  = 14; # 0x0E
    "R"  = 15; # 0x0F
    "Y"  = 16; # 0x10
    "T"  = 17; # 0x11
    "1"  = 18; # 0x12
    "2"  = 19; # 0x13
    "3"  = 20; # 0x14
    "4"  = 21; # 0x15
    "6"  = 22; # 0x16
    "5"  = 23; # 0x17
    "="  = 24; # 0x18
    "9"  = 25; # 0x19
    "7"  = 26; # 0x1A
    "-"  = 27; # 0x1B
    "8"  = 28; # 0x1C
    "0"  = 29; # 0x1D
    "]"  = 30; # 0x1E
    "O"  = 31; # 0x1F
    "U"  = 32; # 0x20
    "["  = 33; # 0x21
    "I"  = 34; # 0x22
    "P"  = 35; # 0x23
    "L"  = 37; # 0x25
    "J"  = 38; # 0x26
    "'"  = 39; # 0x27
    "K"  = 40; # 0x28
    ";"  = 41; # 0x29
   "\\"  = 42; # 0x2A
    ","  = 43; # 0x2B
    "/"  = 44; # 0x2C
    "N"  = 45; # 0x2D
    "M"  = 46; # 0x2E
    "."  = 47; # 0x2F
    "`"  = 50; # 0x32

    "return" = 36;  # 0x24
    "tab"    = 48;  # 0x30
    "space"  = 49;  # 0x31
    "delete" = 51;  # 0x33
    "escape" = 53;  # 0x35
    "left"   = 123; # 0x7B
    "right"  = 124; # 0x7C
    "down"   = 125; # 0x7D
    "up"     = 126; # 0x7E

    "f17" = 64;  # 0x40
    "f18" = 79;  # 0x4F
    "f19" = 80;  # 0x50
    "f20" = 90;  # 0x5A
    "f5"  = 96;  # 0x60
    "f6"  = 97;  # 0x61
    "f7"  = 98;  # 0x62
    "f3"  = 99;  # 0x63
    "f8"  = 100; # 0x64
    "f9"  = 101; # 0x65
    "f11" = 103; # 0x67
    "f13" = 105; # 0x69
    "f16" = 106; # 0x6A
    "f14" = 107; # 0x6B
    "f10" = 109; # 0x6D
    "f12" = 111; # 0x6F
    "f15" = 113; # 0x71
    "f4"  = 118; # 0x76
    "f2"  = 120; # 0x78
    "f1"  = 122; # 0x7A


    "keypad."     = 65; # 0x41
    "keypad*"     = 67; # 0x43
    "keypad+"     = 69; # 0x45
    "keypadClear" = 71; # 0x47
    "keypad/"     = 75; # 0x4B
    "keypadEnter" = 76; # 0x4C
    "keypad-"     = 78; # 0x4E
    "keypad="     = 81; # 0x51
    "keypad0"     = 82; # 0x52
    "keypad1"     = 83; # 0x53
    "keypad2"     = 84; # 0x54
    "keypad3"     = 85; # 0x55
    "keypad4"     = 86; # 0x56
    "keypad5"     = 87; # 0x57
    "keypad6"     = 88; # 0x58
    "keypad7"     = 89; # 0x59
    "keypad8"     = 91; # 0x5B
    "keypad9"     = 92; # 0x5C
  };

  modsOptions = attrsets.genAttrs (attrsets.attrNames modNames) (modName:
    options.mkOption {
      type = types.bool;
      default = false;
      example = true;
      description = "Use the `${modName}` modifier in the combination";
    });

  shortcutOptions = id: enable: mods: key: {
    id = options.mkOption {
      internal = true;
      visible = false;
      readOnly = true;
      default = id;
      type = types.int;
      description = "Shortcut numeric key in the plist dict";
    };
    enable = options.mkOption {
      type = types.bool;
      default = enable;
      example = true;
      description = "Whether to enable this shortcut";
    };
    mods = options.mkOption {
      type = types.submodule { options = modsOptions; };
      default = attrsets.genAttrs mods (_: true);
      description = "Modifiers for this combination";
    };
    key = options.mkOption {
      type = types.nullOr (types.enum (attrsets.attrNames keyCodes));
      example = "delete";
      description = "Final key of the combination";
      default = key;
      apply = val: if val == null then 65535 else attrsets.getAttr val keyCodes;
    };
  };

  mkShortcut = id: description: enable: mods: key:
    options.mkOption {
      inherit description;
      type = types.submodule { options = shortcutOptions id enable mods key; };
      default = {};
      example = options.literalExpression ''
        {
          enable = true;
          mods = {
            option = true;
            control = true;
          };
          key = "delete";
        }
      '';
    };

  encodeShortcut = config: let
    reverseLookup = val: let 
      keys = builtins.attrNames keyCodes;
      matchingKeys = builtins.filter (k: keyCodes.${k} == val) keys;
    in
      if matchingKeys == [] then null else builtins.head matchingKeys;

    # TODO: this is brittle, probably incorrect and based on this comment https://stackoverflow.com/a/23318003 
    # > It is the ascii code of the letter on the key, or -1 (65535) if there is no ascii code. Note that letters are lowercase, so D is 100 (lowercase d).
    # > Sometimes a key that would normally have an ascii code uses 65535 instead. This appears to happen when the control key modifier is used, for example with hot keys for specific spaces.
    keyCodeToAscii = config : 
      let 
        code = config.key;
        mods = config.mods;
        isAsciish = code : (code >=  0 && code < 36)
              || (code >= 37 && code < 48)
              || (code == 50 );
      in
        # Apart from the control modifier, it seems that for instance command option d is 65535
        # deal with ascii-ish keycodes and convert them to an ascii code.
        if (!mods.control && !(mods.command && mods.option) && isAsciish code) then
          (lib.strings.charToInt (lib.strings.toLower (reverseLookup code)))
        # "return"
        else if (!mods.control && code == 36) then 10
        # "tab"
        else if (!mods.control && code == 48) then 9
        # "space"
        else if (!mods.control && code == 49) then 32
        # "delete"
        else if (!mods.control && code == 51) then 127
        # assume (probably incorrectly) that the rest map to the magic code 65535
        else 65535;

  in {
    name = toString config.id;
    value = {
      enabled = config.enable;
      value = {
        parameters = [
          (keyCodeToAscii config)
          config.key
          (lib.pipe modMasks [
            (attrsets.filterAttrs (mod: _: attrsets.getAttr mod config.mods))
            attrsets.attrValues
            (lists.foldl' lib.add 0)
          ])
        ];
        type = "standard";  # No idea what other possible values are
      };
    };
  };

  encodeShortcuts = shortcuts:
    builtins.toJSON (builtins.listToAttrs (map encodeShortcut shortcuts));
in

{
  options.system.keyboard.shortcuts = with modNames; {
    enable = options.mkEnableOption "keyboard shorcuts";

    # the otherwise undocumented complete list of magic numbers for system hotkeys
    # is here https://gist.github.com/mkhl/455002#file-ctrl-f1-c-L12 

    launchpadDock = {
      dockHiding = mkShortcut 52 "Turn Dock hiding on/off" true [option command] "D";
      showLaunchpad = mkShortcut 160 "Show Launchpad" false [] null;
    };

    # TODO: missionControl

    # TODO: keyboard

    inputSources = {
      prev = mkShortcut 60 "Select previous input source" true [control] "space";
      next = mkShortcut 61 "Select next input source" true [control option] "space";
    };

    # TODO: screenshots

    # TODO: services

    spotlight = {
      # search = mkShortcut 64 "Show Spotlight search" true [command] "space";
      # until I learn how to override this correctly
      search = mkShortcut 64 "Show Spotlight search" false [command] "space";
      finderSearch = mkShortcut 65 "Show Finder search" true [option command] "space";
    };

    # TODO: accessibility

    # TODO: appShortcuts
  };

  config =
    let
      # The shortcuts plist uses nested dicts and updating those is _really_
      # tricky without having a real programming language at hand.
      # In particular, `defaults` can’t make sure the nested types are correct
      # and PlistBuddy cannot do “update or create”.
      updateShortcuts = pkgs.writeScript "updateShortcuts.py" ''
        #!${pkgs.python3.interpreter}

        import json
        from os.path import expanduser
        import plistlib
        import sys

        path = expanduser('~/Library/Preferences/com.apple.symbolichotkeys.plist')

        with open(path, 'rb') as f:
          plist = plistlib.load(f)

        with open(sys.argv[1], 'rb') as f:
          updates = json.load(f)

        plist['AppleSymbolicHotKeys'].update(updates)

        with open(path, 'wb') as f:
          plistlib.dump(plist, f)
      '';
      shortcutsSpec = pkgs.writeTextFile {
        name = "shortcutsSpec.json";
        text = encodeShortcuts (attrsets.collect (s: s ? id) cfg);
      };
    in {
      system.activationScripts.shortcuts.text = lib.optionalString cfg.enable ''
        # Configuring system shortcuts
        "${updateShortcuts}" "${shortcutsSpec}"

        # https://zameermanji.com/blog/2021/6/8/applying-com-apple-symbolichotkeys-changes-instantaneously/
        # write to a (hopefully also in the future) unused magic number, so that some hidden state gets updated
        # and activateSettings will reload the plist
        defaults write com.apple.symbolichotkeys.plist AppleSymbolicHotKeys -dict-add 999 "<dict><key>enabled</key><false/></dict>"
        /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u
      '';
    };
}
