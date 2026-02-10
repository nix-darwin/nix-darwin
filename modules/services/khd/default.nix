{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.khd;

  i3Config = import ./i3.nix { inherit pkgs; };
in

{
  options = {
    services.khd.enable = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to enable the khd hotkey daemon.";
    };

    services.khd.package = mkOption {
      type = types.package;
      default = pkgs.khd;
      defaultText = "pkgs.khd";
      description = "This option specifies the khd package to use.";
    };

    services.khd.khdConfig = mkOption {
      type = types.lines;
      default = "";
      example = "alt + shift - r   :   kwmc quit";
      description = "Config to use for {file}`khdrc`.";
    };

    services.khd.i3Keybindings = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to configure i3 style keybindings for kwm.";
    };
  };

  config = mkIf cfg.enable {

    services.khd.khdConfig = mkIf cfg.i3Keybindings i3Config;

    security.accessibilityPrograms = [ "${cfg.package}/bin/khd" ];

    environment.etc."khdrc".text = cfg.khdConfig;

    launchd.user.agents.khd = {
      path = [ cfg.package config.environment.systemPath ];

      serviceConfig.ProgramArguments = [ "${cfg.package}/bin/khd" ]
        ++ optionals (cfg.khdConfig != "") [ "-c" "/etc/khdrc" ];
      serviceConfig.KeepAlive = true;
      serviceConfig.ProcessType = "Interactive";
      serviceConfig.Sockets.Listeners =
        { SockServiceName = "3021";
          SockType = "dgram";
          SockFamily = "IPv4";
        };

      managedBy = "services.khd.enable";
    };

  };
}
