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
                    Path to the log file to rotate.
                  '';
                  example = "/var/log/myapp.log";
                };

                owner = mkOption {
                  type = types.nullOr types.str;
                  default = null;
                  description = ''
                    Owner of the log file.

                    If `null`, no owner will be specified.
                  '';
                  example = "myuser";
                };

                group = mkOption {
                  type = types.nullOr types.str;
                  default = null;
                  description = ''
                    Group of the log file.

                    If `null`, no group will be specified.
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
                    Time-based rotation schedule. Can be:
                    - Hours: @T00, @T06, @T12, @T18 (every 6 hours starting at midnight)
                    - Daily: @T00 (daily at midnight)
                    - Weekly: $W0D00 (weekly on Sunday at midnight)
                    - Monthly: $M1D00 (monthly on the 1st at midnight)

                    If `null`, time-based rotation is disabled.
                  '';
                  example = "@T00";
                };

                flags = mkOption {
                  type = types.listOf types.str;
                  default = [ ];
                  description = ''
                    List of flags for newsyslog. Common flags include:
                    - "B" - Binary file, don't add status message
                    - "C" - Create log file if it doesn't exist
                    - "G" - Indicates that logfilename is a shell pattern
                    - "J" - Compress rotated logs with bzip2
                    - "N" - Don't rotate empty files
                    - "Z" - Compress rotated logs with gzip
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
    environment.etc =
      let
        formatEntry =
          entry:
          let
            ownerGroup =
              if entry.owner != null && entry.group != null then
                "${entry.owner}:${entry.group}"
              else if entry.owner != null then
                entry.owner
              else if entry.group != null then
                ":${entry.group}"
              else
                "";

            baseParts = [
              entry.logfilename
            ]
            ++ (lib.optional (ownerGroup != "") ownerGroup)
            ++ [
              entry.mode
              (toString entry.count)
              (if entry.size != null then entry.size else "*")
              (if entry.when != null then entry.when else "*")
              (lib.concatStrings entry.flags)
            ];

            optionalParts = lib.filter (p: p != null && p != "") [
              entry.pidFile
              entry.signal
            ];
          in
          lib.concatStringsSep "\t" (baseParts ++ optionalParts);

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
