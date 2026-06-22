{ config, lib, ... }:
let
  cfg = config.networking.wifi;
in
{
  options = {
    networking.wifi = {
      AskToJoinNetworks = lib.mkOption {
        type = lib.types.nullOr (
          lib.types.enum [
            "Off"
            "Notify"
            "Ask"
          ]
        );
        default = null;
        example = "Notify";
        description = ''
          Sets the behavior for when no known Wi-Fi network is available:

              Off
                  Known networks will be joined automatically.
                  If no known networks are available, you will have to manually select a network.

              Notify (macOS default)
                  Known networks will be joined automatically.
                  If no known networks are available, you will be notified of available networks.

              Ask
                  Known networks will be joined automatically.
                  If no known networks are available, you will be asked before joining a new network.

          This is equivalent to the setting in 'System Settings > Wi-Fi'
        '';
        apply =
          value:
          if value == "Off" then
            "DoNothing"
          else if value == "Ask" then
            "Prompt"
          else
            value;
      };
      AskToJoinHotspots = lib.mkOption {
        type = lib.types.nullOr (
          lib.types.enum [
            "Never"
            "AskToJoin"
            "Automatic"
          ]
        );
        default = null;
        example = "AskToJoin";
        description = ''
          Sets the behavior for when nearby personal hotspots are detected and no Wi-Fi network is available:

              Never
                  Do nothing

              AskToJoin (macOS default)
                  Show a notification prompting the user to join personal hotspot if it is available

              Automatic
                  Connect to personal hotspot automatically

          This is equivalent to the setting in 'System Settings > Wi-Fi'
        '';
      };
    };
  };

  config = {
    system.defaults.CustomSystemPreferences."/Library/Preferences/SystemConfiguration/com.apple.airport.preferences" =
      {
        AutoHotspotMode = cfg.AskToJoinHotspots;
        JoinModeFallback = [ cfg.AskToJoinNetworks ];
      };
  };
}
