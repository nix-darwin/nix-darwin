{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) maintainers mkEnableOption mkIf mkPackageOption mkOption types;

  cfg = config.services.jankyborders;
  joinStrings = strings: builtins.concatStringsSep "," strings;

  optionalArg = arg: value:
    if value != null && value != ""
    then
      if lib.isList value
      then lib.map (val: "${arg}=${val}") value
      else ["${arg}=${value}"]
    else [];
in {
  meta.maintainers = [
    maintainers.amsynist or "amsynist"
  ];

  options.services.jankyborders = {
    enable = mkEnableOption "the jankyborders service.";

    package = mkPackageOption pkgs "jankyborders" {};

    width = mkOption {
      type = types.float;
      default = 5.0;
      description = ''
        Determines the width of the border. For example, width=5.0 creates a border 5.0 points wide.
      '';
    };

    hidpi = mkOption {
      type = types.bool;
      default = false;
      description = ''
        If set to on, the border will be drawn with retina resolution.
      '';
    };

    active_color = mkOption {
      type = types.str;
      default = "0xFFFFFFFF";
      example = "0xFFFFFFFF";
      description = ''
        Sets the border color for the focused window (format: 0xAARRGGBB). For instance, active_color="0xff00ff00" creates a green border.
        For Gradient Border : active_color="gradient(top_right=0x9992B3F5,bottom_left=0x9992B3F5)"
      '';
    };

    inactive_color = mkOption {
      type = types.str;
      default = "0xFFFFFFFF";
      example = "0xFFFFFFFF";
      description = ''
        Sets the border color for all windows not in focus (format: 0xAARRGGBB).
        For Gradient Border : inactive_color="gradient(top_right=0x9992B3F5,bottom_left=0x9992B3F5)"
      '';
    };

    background_color = mkOption {
      type = types.str;
      default = "";
      example = "0xFFFFFFFF";
      description = ''
        Sets the background fill color for all windows (only 0xAARRGGBB arguments supported).
      '';
    };

    style = mkOption {
      type = types.str;
      default = "round";
      example = "square/round";
      description = ''
        Specifies the style of the border (either round or square).
      '';
    };

    order = mkOption {
      type = types.enum [ "above" "below" ];
      default = "below";
      example = "above";
      description = ''
        Specifies whether borders should be drawn above or below windows.
      '';
    };

    blur_radius = mkOption {
      type = types.float;
      default = 0.0;
      example = 5.0;
      description = ''
        Sets the blur radius applied to the borders or backgrounds with transparency.
      '';
    };

    ax_focus = mkOption {
      type = types.bool;
      default = false;
      description = ''
        If set to true, the (slower) accessibility API is used to resolve the focused window.
      '';
    };

    blacklist = mkOption {
      type = types.listOf types.str;
      default = [];
      example = ["Safari" "kitty"];
      description = ''
        The applications specified here are excluded from being bordered.
        For example, blacklist = [ "Safari" "kitty" ] excludes Safari and kitty from being bordered.
      '';
    };

    whitelist = mkOption {
      type = types.listOf types.str;
      default = [];
      example = ["Arc" "USB Overdrive"];
      description = ''
        Once this list is populated, only applications listed here are considered for receiving a border.
        If the whitelist is empty (default) it is inactive.
      '';
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = !(cfg.blacklist != [] && cfg.whitelist != []);
        message = "Cannot define both a blacklist and a whitelist for jankyborders.";
      }
    ];
    environment.systemPackages = [cfg.package];

    launchd.user.agents.jankyborders = {
      serviceConfig.ProgramArguments =
        [
          "${cfg.package}/bin/borders"
        ]
        ++ (optionalArg "width" (toString cfg.width))
        ++ (optionalArg "hidpi" (
          if cfg.hidpi
          then "on"
          else "off"
        ))
        ++ (optionalArg "active_color" cfg.active_color)
        ++ (optionalArg "inactive_color" cfg.inactive_color)
        ++ (optionalArg "background_color" cfg.background_color)
        ++ (optionalArg "style" cfg.style)
        ++ (optionalArg "blur_radius" (toString cfg.blur_radius))
        ++ (optionalArg "ax_focus" (
          if cfg.ax_focus
          then "on"
          else "off"
        ))
        ++ (optionalArg "blacklist" (joinStrings cfg.blacklist))
        ++ (optionalArg "whitelist" (joinStrings cfg.whitelist))
        ++ (optionalArg "order" cfg.order);
      serviceConfig.KeepAlive = true;
      serviceConfig.RunAtLoad = true;
      managedBy = "services.jankyborders.enable";
    };
  };
}
