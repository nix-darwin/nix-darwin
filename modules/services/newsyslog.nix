# Configure macOS's built-in newsyslog log rotation utility
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.newsyslog;

  # Create a single newsyslog config line. See the following manual page
  # for the exact format:
  # man 5 newsyslog.conf
  mkLine = path: conf:
    let
      # The colon must be included even if you only specify owner or group,
      # but not both
      owner = if conf.owner != null then conf.owner else "";
      group = if conf.group != null then conf.group else "";
      ownerGroup =
        if (conf.owner == null) && (conf.group == null) then
          ""
        else
          "${owner}:${group}";
      flags = if conf.flags != null then conf.flags else "";
      pathToPidFile = if conf.pathToPidFile != null then conf.pathToPidFile else "";
      signalNumber = if conf.signalNumber != null then (toString conf.signalNumber) else "";
    in
    concatStringsSep " " [
      path
      ownerGroup
      conf.mode
      (toString conf.count)
      conf.size
      conf.when
      flags
      pathToPidFile
      signalNumber
    ];

  mkFile = name: moduleConf:
    let
      lines = mapAttrsToList mkLine moduleConf;
    in
    {
      text = ''
        # logfilename                   [owner:group]    mode count size when  flags [/pid_file] [sig_num]
        ${concatStringsSep "\n" lines}
      '';
    };
in
{
  meta.maintainers = [
    maintainers.justuswilhelm or "justuswilhelm"
  ];

  options = {
    services.newsyslog = {
      modules = mkOption {
        default = { };
        type = types.attrsOf (types.attrsOf (types.submodule {
          options = {
            owner = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = "User that new log file belongs to. Defaults to root";
            };

            group = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = "Group that new log file belongs to. Defaults to admin";
            };

            mode = mkOption {
              type = types.str;
              description = "File mode of the log file and archives.";
              example = "640";
              default = "600";
            };

            count = mkOption {
              type = types.int;
              description = "Maximum number of archive files which may exist. Does not consider current log file.";
              example = 10;
              default = 10;
            };

            size = mkOption {
              type = types.str;
              default = "*";
              description = "Size threshold for rotation. Specify '*' for any size.";
            };

            when = mkOption {
              type = types.str;
              default = "$D0";
              description = "When to rotate the log file. Defaults to midnight ($D0).";
            };

            flags = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = "Flags for log rotation behavior.";
            };
            pathToPidFile = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = "Specifies the file name containing the PID of the process writing to this log file.";
            };
            signalNumber = mkOption {
              type = types.nullOr types.int;
              default = null;
              description = "Signal number that newsyslog will send to the log writing process. Defaults to the signal number for SIGHUP.";
            };
          };
        }));
        description = ''
          Newsyslog configuration for log rotation by module.

          Each entry here creates a new newsyslog configuration file in
          /etc/newsyslog.d.
          You can add an arbitrary amount of lines to each newsyslog
          configuration file
          See `man newsyslog.conf` for more information on the newsyslog
          configuration format and `man newsyslog` for more information
          on the newsyslog log rotation utility.
        '';
        example = literalExpression ''
          {
            myapp = {
              "/var/log/myapp.log" = {
                mode = "640";
                count = 10;
                size = "1000";
                when = "$D0";
                flags = "J";
              };
            };
          }
        '';
      };
    };
  };

  config = mkIf (cfg.modules != { }) {
    environment.etc = mapAttrs'
      (name: conf: { name = "newsyslog.d/${name}.conf"; value = mkFile name conf; })
      cfg.modules;
  };
}
