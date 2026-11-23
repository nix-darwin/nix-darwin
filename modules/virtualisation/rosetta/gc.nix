{
  config,
  lib,
  ...
}:

let
  inherit (lib)
    mkEnableOption
    mkIf
    mkOption
    ;

  launchdTypes = import ../../launchd/types.nix { inherit config lib; };

  logFile = "/var/log/rosetta-gc.log";

  cfg = config.virtualisation.rosetta.gc;
in

{
  options.virtualisation.rosetta.gc = {
    enable = mkEnableOption "Rosetta 2 JIT cache garbage collection";

    interval = mkOption {
      type = launchdTypes.StartCalendarInterval;
      default = [
        {
          Weekday = 6;
          Hour = 3;
          Minute = 15;
        }
      ];
      description = ''
        The calendar interval at which the garbage collector will run.
        See the {option}`serviceConfig.StartCalendarInterval` option of
        the {option}`launchd` module for more info.
      '';
    };
  };

  config = mkIf cfg.enable {
    launchd.daemons.rosetta-gc = {
      script = ''
        /System/Library/Filesystems/apfs.fs/Contents/Resources/apfs.util -P -minsize 0 /System/Volumes/Data 2>&1| sed -e "s/^/$(date)| /"
      '';
      serviceConfig = {
        RunAtLoad = true;
        StartCalendarInterval = cfg.interval;
        StandardErrorPath = logFile;
        StandardOutPath = logFile;
      };
    };

    environment.etc."newsyslog.d/rosetta-gc.conf".text = ''
      # logfilename          [owner:group]    mode count size when  flags [/pid_file] [sig_num]
      ${logFile}                              640  10    *    $W0   NJ
    '';
  };
}
