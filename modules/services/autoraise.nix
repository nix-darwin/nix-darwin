{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.autoraise;

  escapeString = str: "\"" + builtins.replaceStrings [ "\"" ] [ "\\\"" ] str + "\"";
  formatVal =
    val:
    if builtins.isList val then
      escapeString (builtins.concatStringsSep "," (map (x: toString x) val))
    else if builtins.isString val then
      escapeString val
    else if builtins.isBool val then
      if val then "true" else "false"
    else
      toString val;
  settings = lib.filterAttrs (_: v: !builtins.isNull v) cfg.settings;
  flags = lib.concatMapAttrsStringSep " " (n: v: "-${n} ${formatVal v}") settings;
in
{
  options = {
    services.autoraise = with lib.types; {
      enable = lib.mkEnableOption "AutoRaise";

      package = lib.mkPackageOption pkgs "autoraise" { };

      settings = lib.mkOption {
        type = submodule {
          freeformType = attrs;
          options = {
            pollMillis = lib.mkOption {
              type = nullOr int;
              default = null;
              description = "How often to poll the mouse position and consider a raise/focus. Lower values increase responsiveness but also CPU load. Minimum = 20 and default = 50.";
            };
            delay = lib.mkOption {
              type = nullOr int;
              default = null;
              description = "Raise delay, specified in units of pollMillis. Disabled if 0. A delay > 1 requires the mouse to stop for a moment before raising.";
            };
            focusDelay = lib.mkOption {
              type = nullOr int;
              default = null;
              description = "Focus delay, specified in units of pollMillis. Disabled if 0. A delay > 1 requires the mouse to stop for a moment before focusing.";
            };
            warpX = lib.mkOption {
              type = nullOr (addCheck float (x: x >= 0 && x <= 1));
              default = null;
              description = "A Factor between 0 and 1. Makes the mouse jump horizontally to the activated window. By default disabled.";
            };
            warpY = lib.mkOption {
              type = nullOr (addCheck float (x: x >= 0 && x <= 1));
              default = null;
              description = "A Factor between 0 and 1. Makes the mouse jump vertically to the activated window. By default disabled.";
            };
            scale = lib.mkOption {
              type = nullOr float;
              default = null;
              description = "Enlarge the mouse for a short period of time after warping it. The default is 2.0. To disable set it to 1.0.";
            };
            altTaskSwitcher = lib.mkOption {
              type = nullOr bool;
              default = null;
              description = "Set to true if you use 3rd party tools to switch between applications (other than standard command-tab).";
            };
            ignoreSpaceChanged = lib.mkOption {
              type = nullOr bool;
              default = null;
              description = "Do not immediately raise/focus after a space change. The default is false.";
            };
            invertIgnoreApps = lib.mkOption {
              type = nullOr bool;
              default = null;
              description = "Turns the ignoreApps parameter into an includeApps parameter. The default is false.";
            };
            ignoreApps = lib.mkOption {
              type = nullOr (listOf str);
              default = null;
              description = "Comma separated list of apps for which you would like to disable focus/raise.";
            };
            ignoreTitles = lib.mkOption {
              type = nullOr (listOf str);
              default = null;
              description = "Comma separated list of window titles (a title can be an ICU regular expression) for which you would like to disable focus/raise.";
            };
            stayFocusedBundleIds = lib.mkOption {
              type = nullOr (listOf str);
              default = null;
              description = "Comma separated list of app bundle identifiers that shouldn't lose focus even when hovering the mouse over another window.";
            };
            disableKey = lib.mkOption {
              type = nullOr (enum [
                "control"
                "option"
                "disabled"
              ]);
              default = null;
              description = "Set to control, option or disabled. This will temporarily disable AutoRaise while holding the specified key. The default is control.";
            };
            mouseDelta = lib.mkOption {
              type = nullOr float;
              default = null;
              description = "Requires the mouse to move a certain distance. 0.0 = most sensitive whereas higher values decrease sensitivity.";
            };
            verbose = lib.mkOption {
              type = nullOr bool;
              default = null;
              description = "Set to true to make AutoRaise show a log of events when started in a terminal.";
            };
          };
        };
        default = { };
        example = lib.literalExpression ''
          {
            pollMillis = 50;
            delay = 1;
            focusDelay = 0;
            warpX = 0.5;
            warpY = 0.1;
            scale = 2.5;
            altTaskSwitcher = false;
            ignoreSpaceChanged = false;
            invertIgnoreApps = false;
            ignoreApps = [ "IntelliJ IDEA" "WebStorm" ];
            ignoreTitles = [ "\\s\\| Microsoft Teams" ];
            stayFocusedBundleIds = [ "com.apple.SecurityAgent" ];
            disableKey = "control";
            mouseDelta = 0.1;
          }
        '';
        description = ''
          AutoRaise configuration, see
          <link xlink:href="https://github.com/sbmpost/AutoRaise"/>
          for supported values.
        '';
      };
    };
  };

  config = (
    lib.mkIf (cfg.enable) {
      environment.systemPackages = [ cfg.package ];

      launchd.user.agents.autoraise = {
        command =
          "${cfg.package}/Applications/AutoRaise.app/Contents/MacOS/AutoRaise"
          + (lib.optionalString (settings != { }) " ${flags}");
        serviceConfig = {
          KeepAlive = true;
          RunAtLoad = true;
        };
      };
    }
  );
}
