{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.sleepwatcher;
in

{
  options = {
    services.sleepwatcher = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Whether to enable the sleepwatcher daemon.";
      };

      package = mkOption {
        type = types.package;
        default = pkgs.darwin.sleepwatcher;
        description = "This option specifies the sleepwatcher package to use.";
      };

      on_sleep = mkOption {
        type = types.nullOr types.lines;
        default = null;
        example = "pmset sleepnow";
        description = "Commands to execute when system goes to sleep.";
      };

      on_wakeup = mkOption {
        type = types.nullOr types.lines;
        default = null;
        example = "say 'Good morning!'";
        description = "Commands to execute when system wakes up.";
      };

      on_display_sleep = mkOption {
        type = types.nullOr types.lines;
        default = null;
        example = "echo 'Display sleeping'";
        description = "Commands to execute when display goes to sleep.";
      };

      on_display_wakeup = mkOption {
        type = types.nullOr types.lines;
        default = null;
        example = "echo 'Display awake'";
        description = "Commands to execute when display wakes up.";
      };

      on_display_dim = mkOption {
        type = types.nullOr types.lines;
        default = null;
        example = "echo 'Display dimmed'";
        description = "Commands to execute when display dims.";
      };

      on_display_undim = mkOption {
        type = types.nullOr types.lines;
        default = null;
        example = "echo 'Display undimmed'";
        description = "Commands to execute when display undims.";
      };

      on_idle = mkOption {
        type = types.nullOr types.lines;
        default = null;
        example = "echo 'User idle'";
        description = "Commands to execute when user becomes idle (requires idleTime).";
      };

      on_idle_resume = mkOption {
        type = types.nullOr types.lines;
        default = null;
        example = "echo 'User active again'";
        description = "Commands to execute when user resumes activity after idle.";
      };

      on_plug = mkOption {
        type = types.nullOr types.lines;
        default = null;
        example = "echo 'Power connected'";
        description = "Commands to execute when power adapter is plugged in.";
      };

      on_unplug = mkOption {
        type = types.nullOr types.lines;
        default = null;
        example = "echo 'Power disconnected'";
        description = "Commands to execute when power adapter is unplugged.";
      };

      idleTime = mkOption {
        type = types.nullOr types.int;
        default = null;
        example = 600;
        description = "Idle time in seconds before executing on_idle command.";
      };

      daemonMode = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Whether to run sleepwatcher as a system daemon (true) or user agent (false).
          Daemon mode runs as root and can execute system-level commands.
          User agent mode runs as the user and is preferred for user-specific actions.
        '';
      };
    };
  };

  config = mkIf cfg.enable (
    let
      sleepScript = pkgs.writeShellScript "sleepwatcher-sleep" cfg.on_sleep;
      wakeupScript = pkgs.writeShellScript "sleepwatcher-wakeup" cfg.on_wakeup;
      displaySleepScript = pkgs.writeShellScript "sleepwatcher-display-sleep" cfg.on_display_sleep;
      displayWakeupScript = pkgs.writeShellScript "sleepwatcher-display-wakeup" cfg.on_display_wakeup;
      displayDimScript = pkgs.writeShellScript "sleepwatcher-display-dim" cfg.on_display_dim;
      displayUndimScript = pkgs.writeShellScript "sleepwatcher-display-undim" cfg.on_display_undim;
      idleScript = pkgs.writeShellScript "sleepwatcher-idle" cfg.on_idle;
      idleResumeScript = pkgs.writeShellScript "sleepwatcher-idle-resume" cfg.on_idle_resume;
      plugScript = pkgs.writeShellScript "sleepwatcher-plug" cfg.on_plug;
      unplugScript = pkgs.writeShellScript "sleepwatcher-unplug" cfg.on_unplug;
      
      launchdConfig = {
        path = [ config.environment.systemPath ];
        serviceConfig = {
          ProgramArguments = [
            "${cfg.package}/bin/sleepwatcher"
            "-V"
          ] ++ optionals (cfg.on_sleep != null) [ "-s" "${sleepScript}" ]
            ++ optionals (cfg.on_wakeup != null) [ "-w" "${wakeupScript}" ]
            ++ optionals (cfg.on_display_sleep != null) [ "-S" "${displaySleepScript}" ]
            ++ optionals (cfg.on_display_wakeup != null) [ "-W" "${displayWakeupScript}" ]
            ++ optionals (cfg.on_display_dim != null) [ "-D" "${displayDimScript}" ]
            ++ optionals (cfg.on_display_undim != null) [ "-E" "${displayUndimScript}" ]
            ++ optionals (cfg.on_idle != null && cfg.idleTime != null) [ "-t" "${toString cfg.idleTime}" "-i" "${idleScript}" ]
            ++ optionals (cfg.on_idle_resume != null) [ "-R" "${idleResumeScript}" ]
            ++ optionals (cfg.on_plug != null) [ "-P" "${plugScript}" ]
            ++ optionals (cfg.on_unplug != null) [ "-U" "${unplugScript}" ];
          KeepAlive = true;
          RunAtLoad = true;
        };
      };
    in
    {
      environment.systemPackages = [ cfg.package ];

      launchd.user.agents.sleepwatcher = mkIf (!cfg.daemonMode) launchdConfig;
      
      launchd.daemons.sleepwatcher = mkIf cfg.daemonMode launchdConfig;
    }
  );
}
