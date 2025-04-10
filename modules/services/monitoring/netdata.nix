{ config, lib, pkgs, ... }:
with lib;
let
  cfg = config.services.netdata;

in {
  meta.maintainers = [ lib.maintainers.rsrohitsingh682 or "rsrohitsingh682" ];

  options = {
    services.netdata = {
      enable = mkEnableOption "Netdata daemon";

      package = lib.mkPackageOption pkgs "netdata" {};

      config = mkOption {
        type = types.lines;
        default = "";
        description = "Custom configuration for Netdata";
      };

      workDir = mkOption {
        type = types.path;
        default = "/var/lib/netdata";
        description = "Working directory for Netdata";
      };

      logDir = mkOption {
        type = types.path;
        default = "/var/log/netdata";
        description = "Log directory for Netdata";
      };

      cacheDir = mkOption {
        type = types.path;
        default = "/var/cache/netdata";
        description = "Cache directory for Netdata";
      };
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];

    launchd.daemons.netdata = {
      serviceConfig = {
        Label = "netdata";
        KeepAlive = true;
        WorkingDirectory = cfg.workDir;
        StandardErrorPath = "${cfg.logDir}/netdata.log";
        StandardOutPath = "${cfg.logDir}/netdata.log";
      };
      command = lib.getExe cfg.package;
    };

    environment.etc."netdata/netdata.conf".text = cfg.config;

    system.activationScripts.preActivation.text = ''
      mkdir -p ${cfg.workDir}
      mkdir -p ${cfg.cacheDir}
    '';
  };
}
