{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
let
  cfg = config.services.netbird;
in
{
  options.services.netbird = {
    enable = mkEnableOption "Netbird daemon";
    package = mkOption {
      type = types.package;
      default = pkgs.netbird;
      defaultText = literalExpression "pkgs.netbird";
      description = "The package to use for netbird";
    };
  };
  config = mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];
    launchd.daemons.netbird = {
      script = ''
        mkdir -p /var/run/netbird /var/lib/netbird
        exec ${cfg.package}/bin/netbird service run
      '';
      serviceConfig = {
        EnvironmentVariables = {
          NB_CONFIG = "/var/lib/netbird/config.json";
          NB_LOG_FILE = "console";
        };
        KeepAlive = true;
        RunAtLoad = true;
        StandardOutPath = "/var/log/netbird.out.log";
        StandardErrorPath = "/var/log/netbird.err.log";
      };
    };
  };
}
