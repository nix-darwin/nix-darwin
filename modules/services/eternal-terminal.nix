{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.services.eternal-terminal;
in
{
  options = {
    services.eternal-terminal = {

      enable = mkEnableOption "Eternal Terminal server";

      package = mkOption {
        type = types.path;
        default = pkgs.eternal-terminal;
        defaultText = "pkgs.eternal-terminal";
        description = "This option specifies the eternal-terminal package to use.";
      };

      port = mkOption {
        default = 2022;
        type = types.port;
        description = ''
          The port the server should listen on. Will use the server's default (2022) if not specified.

          Make sure to open this port in the firewall if necessary.
        '';
      };

      verbosity = mkOption {
        default = 0;
        type = types.enum (lib.range 0 9);
        description = ''
          The verbosity level (0-9).
        '';
      };

      silent = mkOption {
        default = false;
        type = types.bool;
        description = ''
          If enabled, disables all logging.
        '';
      };

      logSize = mkOption {
        default = 20971520;
        type = types.int;
        description = ''
          The maximum log size.
        '';
      };
    };
  };

  config = mkIf cfg.enable {

    # We need to ensure the et package is fully installed because
    # the (remote) et client runs the `etterminal` binary when it
    # connects.
    environment.systemPackages = [ cfg.package ];

    launchd.daemons.eternal-terminal = {
      path = [ cfg.package ];
      serviceConfig = {
        ProgramArguments = [
          "${cfg.package}/bin/etserver"
          "--cfgfile=${pkgs.writeText "et.cfg" ''
            ; et.cfg : Config file for Eternal Terminal
            ;

            [Networking]
            port = ${toString cfg.port}

            [Debug]
            verbose = ${toString cfg.verbosity}
            silent = ${if cfg.silent then "1" else "0"}
            logsize = ${toString cfg.logSize}
          ''}"
        ];
        KeepAlive = true;
        RunAtLoad = true;
        HardResourceLimits.NumberOfFiles = 4096;
        SoftResourceLimits.NumberOfFiles = 4096;
      };
    };
  };
  meta.maintainers = [ lib.maintainers.ryane or "ryane" ];
}
