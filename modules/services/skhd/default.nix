{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.skhd;

  inherit (lib) mkOption types;
in
{
  options.services.skhd = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to enable the skhd hotkey daemon.";
    };

    package = mkOption {
      type = types.package;
      default = pkgs.skhd;
      description = "This option specifies the skhd package to use.";
    };

    skhdConfig = mkOption {
      type = types.lines;
      default = "";
      example = "alt + shift - r   :   chunkc quit";
      description = "Config to use for {file}`skhdrc`.";
    };

    errorLogFile = mkOption {
      type = types.path;
      default = "/tmp/skhd.err.log";
      example = "/Users/khaneliman/Library/Logs/skhd.log";
      description = "Path to the error log file.";
    };

    outLogFile = mkOption {
      type = types.path;
      default = "/tmp/skhd.out.log";
      example = "/Users/khaneliman/Library/Logs/skhd.log";
      description = "Path to the stdout log file.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment = {
      systemPackages = [ cfg.package ];
      etc."skhdrc".text = cfg.skhdConfig;
    };

    launchd.user.agents.skhd = {
      path = [ config.environment.systemPath ];

      serviceConfig = {
        ProgramArguments =
          [ "${cfg.package}/bin/skhd" ]
          ++ lib.optionals (cfg.skhdConfig != "") [
            "-c"
            "/etc/skhdrc"
          ];
        KeepAlive = true;
        ProcessType = "Interactive";
        StandardErrorPath = cfg.errorLogFile;
        StandardOutPath = cfg.outLogFile;
      };
    };
  };
}
