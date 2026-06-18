{ lib, pkgs, ... }:

let
  defaultsType = lib.types.submodule {
    freeformType = (pkgs.formats.plist { }).type;
  };
in {
  options = {
    system.defaults.CustomUserPreferences = lib.mkOption {
      type = defaultsType;
      default = { };
      example = {
        "NSGlobalDomain" = { "TISRomanSwitchState" = 1; };
        "com.apple.Safari" = {
          "com.apple.Safari.ContentPageGroupIdentifier.WebKit2DeveloperExtrasEnabled" =
            true;
        };
      };
      description = ''
        Sets custom user preferences
      '';
    };

    system.defaults.CustomSystemPreferences = lib.mkOption {
      type = defaultsType;
      default = { };
      example = {
        "NSGlobalDomain" = { "TISRomanSwitchState" = 1; };
        "com.apple.Safari" = {
          "com.apple.Safari.ContentPageGroupIdentifier.WebKit2DeveloperExtrasEnabled" =
            true;
        };
      };
      description = ''
        Sets custom system preferences
      '';
    };

  };
}
