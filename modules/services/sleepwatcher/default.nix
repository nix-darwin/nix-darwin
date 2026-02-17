{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.sleepwatcher;
in

{
  options = {
    services.sleepwatcher = {
      enable = mkEnableOption "sleepwatcher daemon to react to various system events";

      package = mkPackageOption pkgs [ "sleepwatcher" ] { };

      verbose = mkOption {
        type = types.bool;
        default = true;
        description = "Whether to verbosely log actions performed by sleepwatcher.";
      };

      logFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        example = "/var/log/sleepwatcher.log";
        description = ''
          The log file path for sleepwatcher output.
          If set, both stdout and stderr will be logged to this file.
          If not set, logs will be discarded.
        '';
      };

      on_sleep = mkOption {
        type = types.lines;
        default = "";
        example = "echo 'Going to sleep'";
        description = "Commands to execute when system goes to sleep.";
      };

      on_wakeup = mkOption {
        type = types.lines;
        default = "";
        example = "echo 'Waking from sleep'";
        description = "Commands to execute when system wakes up.";
      };

      on_display_sleep = mkOption {
        type = types.lines;
        default = "";
        example = "echo 'Display sleeping'";
        description = ''
          Commands to execute when display goes to sleep.
          
          Note: The --displaysleep option does not work with Apple silicon Macs.
        '';
      };

      on_display_wakeup = mkOption {
        type = types.lines;
        default = "";
        example = "echo 'Display awake'";
        description = ''
          Commands to execute when display wakes up.
          
          Note: The --displaywakeup option does not work with Apple silicon Macs.
        '';
      };

      on_display_dim = mkOption {
        type = types.lines;
        default = "";
        example = "echo 'Display dimmed'";
        description = ''
          Commands to execute when display dims.
          
          Note: The --displaydim option does not work with Apple silicon Macs.
        '';
      };

      on_display_undim = mkOption {
        type = types.lines;
        default = "";
        example = "echo 'Display undimmed'";
        description = ''
          Commands to execute when display undims.
          
          Note: The --displayundim option does not work with Apple silicon Macs.
        '';
      };

      on_plug = mkOption {
        type = types.lines;
        default = "";
        example = "echo 'Power connected'";
        description = "Commands to execute when power adapter is plugged in.";
      };

      on_unplug = mkOption {
        type = types.lines;
        default = "";
        example = "echo 'Power disconnected'";
        description = "Commands to execute when power adapter is unplugged.";
      };

      idle_time = mkOption {
        type = types.nullOr types.int;
        default = null;
        example = 600;
        description = "Idle time in seconds before executing on_idle commands.";
      };

      on_idle = mkOption {
        type = types.lines;
        default = "";
        example = "echo 'User idle'";
        description = "Commands to execute when user becomes idle (requires idle_time to be set).";
      };

      on_idle_resume = mkOption {
        type = types.lines;
        default = "";
        example = "echo 'User active again'";
        description = "Commands to execute when user resumes activity after idle (requires idle_time to be set).";
      };

      run_as_system = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Whether to run sleepwatcher as a system daemon (true) or user agent (false).
          System daemon runs as root and can execute system-level commands.
          User agent runs as the user and is preferred for user-specific actions.
        '';
      };
    };
  };

  config = mkIf cfg.enable (
    let
      optionalHook = longArg: hookValue:
        let hookScript = pkgs.writeShellScript "sleepwatcher-${longArg}-hook" hookValue;
        in optionals (hookValue != "") [ "--${longArg}" "${hookScript}" ];

      launchdConfig = {
        command = concatStringsSep " " (
          [ "${cfg.package}/bin/sleepwatcher" ]
          ++ optionals (cfg.verbose && cfg.logFile != null) [ "--verbose" ]
          ++ optionalHook "sleep" cfg.on_sleep
          ++ optionalHook "wakeup" cfg.on_wakeup
          ++ optionalHook "displaysleep" cfg.on_display_sleep
          ++ optionalHook "displaywakeup" cfg.on_display_wakeup
          ++ optionalHook "displaydim" cfg.on_display_dim
          ++ optionalHook "displayundim" cfg.on_display_undim
          ++ optionals (cfg.idle_time != null)
            ([ "--timeout" "${toString cfg.idle_time}" ] ++
            (optionalHook "idle" cfg.on_idle) ++
            (optionalHook "idleresume" cfg.on_idle_resume))
          ++ optionalHook "plug" cfg.on_plug
          ++ optionalHook "unplug" cfg.on_unplug
        );
        serviceConfig = {
          KeepAlive = true;
          RunAtLoad = true;
        } // (optionalAttrs (cfg.logFile != null) {
          StandardOutPath = cfg.logFile;
          StandardErrorPath = cfg.logFile;
        });
      };
    in
    {
      launchd.user.agents.sleepwatcher = mkIf (!cfg.run_as_system) (launchdConfig // { managedBy = "services.sleepwatcher.enable"; });

      launchd.daemons.sleepwatcher = mkIf cfg.run_as_system launchdConfig;
    }
  );
}
