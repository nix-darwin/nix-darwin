# /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/System/Library/Frameworks/IOKit.framework/Headers/hidsystem/IOLLEvent.h
{
  modMasks = {
    shift = 131072; # 0x00020000
    control = 262144; # 0x00040000
    option = 524288; # 0x00080000
    command = 1048576; # 0x00100000
    fn = 8388608; # 0x00800000
  };

  # /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/System/Library/Frameworks/Carbon.framework/Frameworks/HIToolbox.framework/Headers/Events.h
  # 65535 is a special ASCII code that is required if the keycode isn't a valid
  # ASCII character. Note that some of them are valid, but trial and error
  # showed that Apple doesn't want them marked as such.
  keycodes = {
    # ANSI keycodes
    "a" = {
      decimal = 0;
      ascii = 97;
    };
    "s" = {
      decimal = 1;
      ascii = 115;
    };
    "d" = {
      decimal = 2;
      ascii = 100;
    };
    "f" = {
      decimal = 3;
      ascii = 102;
    };
    "h" = {
      decimal = 4;
      ascii = 104;
    };
    "g" = {
      decimal = 5;
      ascii = 103;
    };
    "z" = {
      decimal = 6;
      ascii = 122;
    };
    "x" = {
      decimal = 7;
      ascii = 120;
    };
    "c" = {
      decimal = 8;
      ascii = 99;
    };
    "v" = {
      decimal = 9;
      ascii = 118;
    };
    "b" = {
      decimal = 11;
      ascii = 98;
    };
    "q" = {
      decimal = 12;
      ascii = 113;
    };
    "w" = {
      decimal = 13;
      ascii = 119;
    };
    "e" = {
      decimal = 14;
      ascii = 101;
    };
    "r" = {
      decimal = 15;
      ascii = 114;
    };
    "y" = {
      decimal = 16;
      ascii = 121;
    };
    "t" = {
      decimal = 17;
      ascii = 116;
    };
    "1" = {
      decimal = 18;
      ascii = 49;
    };
    "2" = {
      decimal = 19;
      ascii = 50;
    };
    "3" = {
      decimal = 20;
      ascii = 51;
    };
    "4" = {
      decimal = 21;
      ascii = 52;
    };
    "6" = {
      decimal = 22;
      ascii = 54;
    };
    "5" = {
      decimal = 23;
      ascii = 53;
    };
    "=" = {
      decimal = 24;
      ascii = 61;
    };
    "9" = {
      decimal = 25;
      ascii = 57;
    };
    "7" = {
      decimal = 26;
      ascii = 55;
    };
    "-" = {
      decimal = 27;
      ascii = 45;
    };
    "8" = {
      decimal = 28;
      ascii = 56;
    };
    "0" = {
      decimal = 29;
      ascii = 48;
    };
    "]" = {
      decimal = 30;
      ascii = 93;
    };
    "o" = {
      decimal = 31;
      ascii = 111;
    };
    "u" = {
      decimal = 32;
      ascii = 117;
    };
    "[" = {
      decimal = 33;
      ascii = 91;
    };
    "i" = {
      decimal = 34;
      ascii = 105;
    };
    "p" = {
      decimal = 35;
      ascii = 112;
    };
    "l" = {
      decimal = 37;
      ascii = 108;
    };
    "j" = {
      decimal = 38;
      ascii = 106;
    };
    "'" = {
      decimal = 39;
      ascii = 39;
    };
    "k" = {
      decimal = 40;
      ascii = 107;
    };
    ";" = {
      decimal = 41;
      ascii = 59;
    };
    "\\" = {
      decimal = 42;
      ascii = 92;
    };
    "," = {
      decimal = 43;
      ascii = 44;
    };
    "/" = {
      decimal = 44;
      ascii = 47;
    };
    "n" = {
      decimal = 45;
      ascii = 110;
    };
    "m" = {
      decimal = 46;
      ascii = 109;
    };
    "." = {
      decimal = 47;
      ascii = 46;
    };
    "`" = {
      decimal = 50;
      ascii = 96;
    };
    "Keypad." = {
      decimal = 65;
      ascii = 46;
    };
    "Keypad*" = {
      decimal = 67;
      ascii = 42;
    };
    "Keypad+" = {
      decimal = 69;
      ascii = 43;
    };
    "KeypadClear" = {
      decimal = 71;
      ascii = 65535;
    };
    "Keypad/" = {
      decimal = 75;
      ascii = 47;
    };
    "KeypadEnter" = {
      decimal = 76;
      ascii = 13;
    };
    "Keypad-" = {
      decimal = 78;
      ascii = 45;
    };
    "Keypad=" = {
      decimal = 81;
      ascii = 61;
    };
    "Keypad0" = {
      decimal = 82;
      ascii = 48;
    };
    "Keypad1" = {
      decimal = 83;
      ascii = 49;
    };
    "Keypad2" = {
      decimal = 84;
      ascii = 50;
    };
    "Keypad3" = {
      decimal = 85;
      ascii = 51;
    };
    "Keypad4" = {
      decimal = 86;
      ascii = 52;
    };
    "Keypad5" = {
      decimal = 87;
      ascii = 53;
    };
    "Keypad6" = {
      decimal = 88;
      ascii = 54;
    };
    "Keypad7" = {
      decimal = 89;
      ascii = 55;
    };
    "Keypad8" = {
      decimal = 91;
      ascii = 56;
    };
    "Keypad9" = {
      decimal = 92;
      ascii = 57;
    };

    # Layout-independent keycodes
    "Return" = {
      decimal = 36;
      ascii = 65535;
    };
    "Tab" = {
      decimal = 48;
      ascii = 65535;
    };
    "Space" = {
      decimal = 49;
      ascii = 32;
    };
    "Delete" = {
      decimal = 51;
      ascii = 65535;
    };
    "Escape" = {
      decimal = 53;
      ascii = 65535;
    };
    "Command" = {
      decimal = 55;
      ascii = 65535;
    };
    "Shift" = {
      decimal = 56;
      ascii = 65535;
    };
    "CapsLock" = {
      decimal = 57;
      ascii = 65535;
    };
    "Option" = {
      decimal = 58;
      ascii = 65535;
    };
    "Control" = {
      decimal = 59;
      ascii = 65535;
    };
    "RightCommand" = {
      decimal = 54;
      ascii = 65535;
    };
    "RightShift" = {
      decimal = 60;
      ascii = 65535;
    };
    "RightOption" = {
      decimal = 61;
      ascii = 65535;
    };
    "RightControl" = {
      decimal = 62;
      ascii = 65535;
    };
    "Function" = {
      decimal = 63;
      ascii = 65535;
    };
    "F17" = {
      decimal = 64;
      ascii = 65535;
    };
    "VolumeUp" = {
      decimal = 72;
      ascii = 65535;
    };
    "VolumeDown" = {
      decimal = 73;
      ascii = 65535;
    };
    "Mute" = {
      decimal = 74;
      ascii = 65535;
    };
    "F18" = {
      decimal = 79;
      ascii = 65535;
    };
    "F19" = {
      decimal = 80;
      ascii = 65535;
    };
    "F20" = {
      decimal = 90;
      ascii = 65535;
    };
    "F5" = {
      decimal = 96;
      ascii = 65535;
    };
    "F6" = {
      decimal = 97;
      ascii = 65535;
    };
    "F7" = {
      decimal = 98;
      ascii = 65535;
    };
    "F3" = {
      decimal = 99;
      ascii = 65535;
    };
    "F8" = {
      decimal = 100;
      ascii = 65535;
    };
    "F9" = {
      decimal = 101;
      ascii = 65535;
    };
    "F11" = {
      decimal = 103;
      ascii = 65535;
    };
    "F13" = {
      decimal = 105;
      ascii = 65535;
    };
    "F16" = {
      decimal = 106;
      ascii = 65535;
    };
    "F14" = {
      decimal = 107;
      ascii = 65535;
    };
    "F10" = {
      decimal = 109;
      ascii = 65535;
    };
    "ContextualMenu" = {
      decimal = 110;
      ascii = 65535;
    };
    "F12" = {
      decimal = 111;
      ascii = 65535;
    };
    "F15" = {
      decimal = 113;
      ascii = 65535;
    };
    "Help" = {
      decimal = 114;
      ascii = 65535;
    };
    "Home" = {
      decimal = 115;
      ascii = 65535;
    };
    "PageUp" = {
      decimal = 116;
      ascii = 65535;
    };
    "ForwardDelete" = {
      decimal = 117;
      ascii = 65535;
    };
    "F4" = {
      decimal = 118;
      ascii = 65535;
    };
    "End" = {
      decimal = 119;
      ascii = 65535;
    };
    "F2" = {
      decimal = 120;
      ascii = 65535;
    };
    "PageDown" = {
      decimal = 121;
      ascii = 65535;
    };
    "F1" = {
      decimal = 122;
      ascii = 65535;
    };
    "LeftArrow" = {
      decimal = 123;
      ascii = 65535;
    };
    "RightArrow" = {
      decimal = 124;
      ascii = 65535;
    };
    "DownArrow" = {
      decimal = 125;
      ascii = 65535;
    };
    "UpArrow" = {
      decimal = 126;
      ascii = 65535;
    };
  };
}
