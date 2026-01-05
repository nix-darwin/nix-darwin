{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.spacebar;

  toSpacebarConfig = opts:
    concatStringsSep "\n" (mapAttrsToList
      (p: v: "spacebar -m config ${p} ${toString v}") opts);

  configFile = mkIf (cfg.config != {} || cfg.extraConfig != "")
    "${pkgs.writeScript "spacebarrc" (
      (if (cfg.config != {})
       then "${toSpacebarConfig cfg.config}"
       else "")
      + optionalString (cfg.extraConfig != "") cfg.extraConfig)}";
in

{
  options = with types; {
    services.spacebar.enable = mkOption {
      type = bool;
      default = false;
      description = "Whether to enable the spacebar.";
    };

    services.spacebar.package = mkOption {
      type = path;
      description = "The spacebar package to use.";
    };

    services.spacebar.config = mkOption {
      type = attrs;
      default = {};
      example = literalExpression ''
        {
          clock_format     = "%R";
          background_color = "0xff202020";
          foreground_color = "0xffa8a8a8";
        }
      '';
      description = ''
        Key/Value pairs to pass to spacebar's 'config' domain, via the configuration file.
      '';
    };

    services.spacebar.extraConfig = mkOption {
      type = str;
      default = "";
      example = literalExpression ''
        echo "spacebar config loaded..."
      '';
      description = ''
        Extra arbitrary configuration to append to the configuration file.
      '';
    };
  };

  config = mkIf (cfg.enable) {
    environment.systemPackages = [ cfg.package ];

    launchd.user.agents.spacebar = {
      serviceConfig.ProgramArguments = [ "${cfg.package}/bin/spacebar" ]
                                       ++ optionals (cfg.config != {} || cfg.extraConfig != "") [ "-c" configFile ];

      serviceConfig.KeepAlive = true;
      serviceConfig.RunAtLoad = true;
      serviceConfig.EnvironmentVariables = {
        PATH = "${cfg.package}/bin:${config.environment.systemPath}";
      };

      managedBy = "services.spacebar.enable";
    };
  };
}
