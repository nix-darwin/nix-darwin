{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.rift;
  format = pkgs.formats.toml { };
  configFile = format.generate "config.toml" cfg.config;
in
{
  meta.maintainers = [ lib.maintainers.nrabulinski or "nrabulinski" ];

  options.services.rift = {
    enable = lib.mkEnableOption "rift window manager";
    package = lib.mkPackageOption pkgs "rift-wm" { };
    config = lib.mkOption {
      inherit (format) type;
      default = { };
      example = {
        settings = {
          animate = true;
          default_disable = false;
          focus_follows_mouse = false;
        };
        keys = {
          "Meta + Z" = "toggle_space_activated";
          "Meta + H".move_focus = "left";
          "Meta + J".move_focus = "down";
          "Meta + K".move_focus = "up";
          "Meta + L".move_focus = "right";
        };
      };
      description = ''
        Contents of Rift's configuration file. If empty, ~/.config/rift/config.toml will be loaded
        if present, or [the default](https://github.com/acsandmann/rift/blob/main/rift.default.toml) config will be used.

        See [documentation](https://github.com/acsandmann/rift/wiki/Config) for existing options and examples.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];

    launchd.user.agents.rift = {
      serviceConfig = {
        ProgramArguments = [
          "${lib.getExe cfg.package}"
        ]
        ++ lib.optionals (cfg.config != { }) [
          "--config"
          (toString configFile)
        ];
        RunAtLoad = true;
        KeepAlive.SuccessfulExit = false;
        KeepAlive.Crashed = true;
        ProcessType = "Interactive";
        LimitLoadToSessionType = "Aqua";
        Nice = -20;
      };
      path = [
        cfg.package
        config.environment.systemPath
      ];
      managedBy = "services.rift.enable";
    };
  };
}
