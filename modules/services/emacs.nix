{ config, lib, pkgs, ... }:

with lib;

let

  cfg = config.services.emacs;

in {
  options = {
    services.emacs = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Whether to enable the Emacs Daemon.";
      };

      package = mkOption {
        type = types.path;
        default = pkgs.emacs;
        description = "This option specifies the emacs package to use.";
      };

      additionalPath = mkOption {
        type = types.listOf types.str;
        default = [ ];
        example = [ "/Users/my_user_name" ];
        description = ''
          This option specifies additional PATH that the emacs daemon would have.
          Typically if you have binaries in your home directory that is what you would add your home path here.
          One caveat is that there won't be shell variable expansion, so you can't use $HOME for example
        '';
      };

      exec = mkOption {
        type = types.str;
        default = "emacs";
        description = "Emacs command/binary to execute.";
      };
    };
  };

  config = mkIf cfg.enable {

    launchd.user.agents.emacs = {
      path = cfg.additionalPath ++ [ config.environment.systemPath ];
      serviceConfig = {
        ProgramArguments = [ "${cfg.package}/bin/${cfg.exec}" "--fg-daemon" ];
        RunAtLoad = true;
        KeepAlive = true;
      };
      managedBy = "services.emacs.enable";
    };

  };
}
