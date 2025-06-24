{ config, lib, pkgs, ... }:

let
  inherit (lib) literalExpression maintainers mkEnableOption mkIf mkPackageOption mkOption optionals types;

  cfg = config.services.sketchybar;

  configFile = pkgs.writeScript "sketchybarrc" cfg.config;
in

{

  meta.maintainers = [
    maintainers.azuwis or "azuwis"
  ];

  options.services.sketchybar = {
    enable = mkEnableOption "sketchybar";

    package = mkPackageOption pkgs "sketchybar" { };

    extraPackages = mkOption {
      type = types.listOf types.package;
      default = [ ];
      example = literalExpression "[ pkgs.jq ]";
      description = ''
        Extra packages to add to PATH.
      '';
    };

    config = mkOption {
      type = types.lines;
      default = "";
      example = ''
        sketchybar --bar height=24
        sketchybar --update
        echo "sketchybar configuration loaded.."
      '';
      description = ''
        Contents of sketchybar's configuration file. If empty (the default), the configuration file won't be managed.

        See [documentation](https://felixkratz.github.io/SketchyBar/)
        and [example](https://github.com/FelixKratz/SketchyBar/blob/master/sketchybarrc).
      '';
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];

    launchd.user.agents.sketchybar = {
      path = [ cfg.package ] ++ cfg.extraPackages ++ [ config.environment.systemPath ];
      serviceConfig.ProgramArguments = [ "${cfg.package}/bin/sketchybar" ]
        ++ optionals (cfg.config != "") [ "--config" "${configFile}" ];
      serviceConfig.KeepAlive = true;
      serviceConfig.RunAtLoad = true;
      managedBy = "services.sketchybar.enable";
    };
  };
}
