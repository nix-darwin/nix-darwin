{ config, lib, ... }:

let
  inherit (lib) mkOption types;

  cfg = config.system.newsyslog;
in
{
  options = {
    system.newsyslog = {
      enable = lib.mkEnableOption "newsyslog configuration management";

      files = mkOption {
        type = types.attrsOf (
          types.listOf (
            types.submodule {
              options = {
                logfilename = mkOption {
                  type = types.str;
                  description = ''
                    Path to the log file to rotate, or the literal string `<default>`.

                    The `<default>` entry applies when newsyslog is invoked with an explicit
                    log file argument that does not match another entry.
                  '';
                  example = "/var/log/myapp.log";
                };

                owner = mkOption {
                  type = types.nullOr types.str;
                  default = null;
                  description = ''
                    Owner of the log file.

                    If `null`, the owner portion of `owner:group` is left blank.
                    See `newsyslog.conf(5)` for default ownership behavior (`root:admin`).
                  '';
                  example = "myuser";
                };

                group = mkOption {
                  type = types.nullOr types.str;
                  default = null;
                  description = ''
                    Group of the log file.

                    If `null`, the group portion of `owner:group` is left blank.
                    See `newsyslog.conf(5)` for default ownership behavior (`root:admin`).
                  '';
                  example = "wheel";
                };

                mode = mkOption {
                  type = types.str;
                  default = "644";
                  description = ''
                    File mode (permissions) for the rotated log file.
                  '';
                  example = "600";
                };

                count = mkOption {
                  type = types.ints.unsigned;
                  default = 5;
                  description = ''
                    Number of rotated log files to keep.
                  '';
                };

                size = mkOption {
                  type = types.nullOr types.str;
                  default = null;
                  description = ''
                    Maximum size (in KB) before rotation (e.g., "100", "1024", "4096").

                    If `null`, size-based rotation is disabled.
                  '';
                  example = "2048";
                };

                when = mkOption {
                  type = types.nullOr types.str;
                  default = null;
                  description = ''
                    Time-based rotation schedule.

                    The value may be an interval in hours, a specific time, or both.
                    If both are specified, both conditions must be satisfied.

                    Examples:
                    - Interval only: 24
                    - Daily: @T00 (daily at midnight)
                    - Interval and time: 24@T00
                    - Weekly: $W0D00 (weekly on Sunday at midnight)
                    - Monthly: $M1D00 (monthly on the 1st at midnight)

                    If `null`, time-based rotation is disabled.
                  '';
                  example = "@T00";
                };

                flags = mkOption {
                  type = types.listOf (
                    types.enum [
                      "B"
                      "C"
                      "D"
                      "G"
                      "J"
                      "N"
                      "U"
                      "Z"
                      "-"
                    ]
                  );
                  default = [ ];
                  description = ''
                    List of flags for newsyslog.
                    - "B" - Binary file, don't add status message
                    - "C" - Create log file if missing when newsyslog runs with `-C`/`-CC`
                    - "D" - Mark rotated files with the UF_NODUMP flag
                    - "G" - Indicates that logfilename is a shell pattern
                    - "J" - Compress rotated logs with bzip2
                    - "N" - Do not signal a daemon after rotating this log
                    - "U" - pidFile points to a process group ID (negative value)
                    - "Z" - Compress rotated logs with gzip
                    - "-" - Placeholder when specifying pidFile/signal without other flags
                  '';
                  example = [
                    "Z"
                    "C"
                  ];
                };

                pidFile = mkOption {
                  type = types.nullOr types.str;
                  default = null;
                  description = ''
                    Path to PID file.

                    If specified, the process will be signaled after rotation.
                    This path must be absolute (start with `/`).
                  '';
                  example = "/var/run/myapp.pid";
                };

                signal = mkOption {
                  type = types.nullOr types.str;
                  default = null;
                  description = ''
                    Signal to send to the process (default is SIGHUP if pidFile is specified).
                    Can be signal name (HUP, USR1, etc.) or number.
                  '';
                  example = "USR1";
                };
              };
            }
          )
        );
        default = { };
        description = ''
          Attribute set of newsyslog configuration files to create in /etc/newsyslog.d/.

          Each attribute name becomes the filename (with .conf extension automatically added).
          Each attribute value is a list of log rotation entries.
        '';
        example = lib.literalExpression ''
          {
            myapp = [
              {
                logfilename = "/var/log/myapp.log";
                owner = "myuser";
                group = "wheel";
                mode = "644";
                count = 7;
                size = "10M";
                flags = [ "Z" "C" ];
                pidFile = "/var/run/myapp.pid";
                signal = "USR1";
              }
            ];
            system = [
              {
                logfilename = "/var/log/system.log";
                mode = "644";
                count = 5;
                when = "@T00";
                flags = [ "Z" ];
              }
            ];
          }
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = lib.flatten (
      lib.mapAttrsToList (
        fileName: entries:
        lib.flatten (
          lib.imap0 (index: entry: [
            {
              assertion = entry.signal == null || entry.pidFile != null;
              message = "system.newsyslog.files.${fileName}[${toString index}].signal requires pidFile to be set.";
            }
            {
              assertion = entry.pidFile == null || builtins.match "/.*" entry.pidFile != null;
              message = "system.newsyslog.files.${fileName}[${toString index}].pidFile must be an absolute path starting with '/'.";
            }
          ]) entries
        )
      ) cfg.files
    );

    environment.etc =
      let
        orStar = value: if value == null then "*" else value;

        formatOwnerGroup =
          entry:
          "${lib.optionalString (entry.owner != null) entry.owner}:${
            lib.optionalString (entry.group != null) entry.group
          }";

        formatFlags =
          entry:
          lib.optional (entry.flags != [ ]) (lib.concatStrings entry.flags)
          ++ lib.optional (entry.flags == [ ] && (entry.pidFile != null || entry.signal != null)) "-";

        formatEntry =
          entry:
          lib.concatStringsSep "\t" (
            [
              entry.logfilename
            ]
            ++ lib.optional (entry.owner != null || entry.group != null) (formatOwnerGroup entry)
            ++ [
              entry.mode
              (toString entry.count)
              (orStar entry.size)
              (orStar entry.when)
            ]
            ++ formatFlags entry
            ++ lib.optionals (entry.pidFile != null) [ entry.pidFile ]
            ++ lib.optionals (entry.signal != null) [ entry.signal ]
          );

        generateFileContent = entries: ''
          # Generated by nix-darwin
          # logfilename [owner:group] mode count size when flags [/pid_file] [sig_num]
          ${lib.concatMapStringsSep "\n" formatEntry entries}
        '';
      in
      lib.mapAttrs' (name: entries: {
        name = "newsyslog.d/${name}.conf";
        value.text = generateFileContent entries;
      }) cfg.files;
  };
}
