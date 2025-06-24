{ config, lib, ... }:

with lib;

let
  valueType = with lib.types; nullOr (oneOf [
    bool
    int
    float
    str
    path
    (attrsOf valueType)
    (listOf valueType)
  ]) // {
    description = "plist value";
  };
  defaultsType = types.submodule {
    freeformType = valueType;
  };
in {
  options = {
    system.defaults.CustomUserPreferences = mkOption {
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

    system.defaults.CustomSystemPreferences = mkOption {
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
