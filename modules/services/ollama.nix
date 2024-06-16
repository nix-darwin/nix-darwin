{ config, lib, pkgs, ... }:

with lib;

let

  cfg = config.services.ollama;

in {
  options = {
    services.ollama = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Whether to enable the Ollama Daemon.";
      };

      package = mkOption {
        type = types.path;
        default = pkgs.ollama;
        description = "This option specifies the ollama package to use.";
      };

      exec = mkOption {
        type = types.str;
        default = "ollama";
        description = "Ollama command/binary to execute.";
      };
    };
  };

  config = mkIf cfg.enable {
    launchd.daemons.ollama = {
      path = [ config.environment.systemPath ];
      serviceConfig.ProgramArguments =
        [ "${cfg.package}/bin/${cfg.exec}" "serve" ];
      serviceConfig.RunAtLoad = true;
    };
  };
}
