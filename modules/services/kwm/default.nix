{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.kwm;
in

{
  options = {
    services.kwm.enable = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to enable the khd window manager.";
    };

    services.kwm.package = mkOption {
      type = types.path;
      default = pkgs.kwm;
      defaultText = "pkgs.kwm";
      description = "This option specifies the kwm package to use.";
    };

    services.kwm.kwmConfig = mkOption {
      type = types.lines;
      default = "";
      example = ''kwmc rule owner="iTerm2" properties={role="AXDialog"}'';
      description = "Config to use for {file}`kwmrc`.";
    };
  };

  config = mkIf cfg.enable {

    security.accessibilityPrograms = [ "${cfg.package}/kwm" ];

    environment.systemPackages = [ cfg.package ];

    environment.etc."kwmrc".text = cfg.kwmConfig;

    launchd.user.agents.kwm = {
      serviceConfig.ProgramArguments = [ "${cfg.package}/kwm" ]
        ++ optionals (cfg.kwmConfig != "") [ "-c" "/etc/kwmrc" ];
      serviceConfig.KeepAlive = true;
      serviceConfig.ProcessType = "Interactive";
      serviceConfig.Sockets.Listeners =
        { SockServiceName = "3020";
          SockType = "dgram";
          SockFamily = "IPv4";
        };
      managedBy = "services.kwm.enable";
    };

  };
}
