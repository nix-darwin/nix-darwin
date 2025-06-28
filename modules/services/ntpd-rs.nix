{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.ntpd-rs;
  format = pkgs.formats.toml { };
  configFile = format.generate "ntpd-rs.toml" cfg.settings;
in
{
  options.services.ntpd-rs = {
    enable = lib.mkEnableOption "Network Time Service (ntpd-rs)";
    metrics.enable = lib.mkEnableOption "ntpd-rs Prometheus Metrics Exporter";

    package = lib.mkPackageOption pkgs "ntpd-rs" { };

    settings = lib.mkOption {
      type = lib.types.submodule {
        freeformType = format.type;
      };
      default = { };
      description = ''
        Settings to write to {file}`ntp.toml`

        See <https://docs.ntpd-rs.pendulum-project.org/man/ntp.toml.5>
        for more information about available options.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];

    services.ntpd-rs.settings = {
      observability = {
        observation-path = lib.mkDefault "/var/run/ntpd-rs/observe";
      };
    };

    launchd.daemons.ntpd-rs = {
      script = ''
        mkdir -p "$(dirname ${cfg.settings.observability.observation-path})"
        exec ${lib.getExe' cfg.package "ntp-daemon"} --config=${configFile}
      '';
      environment.USER = "root";
      serviceConfig.KeepAlive = true;
      serviceConfig.RunAtLoad = true;
    };

    launchd.daemons.ntpd-rs-metrics = lib.mkIf cfg.metrics.enable {
      script = ''
        exec ${lib.getExe' cfg.package "ntp-metrics-exporter"} --config=${configFile}
      '';
      environment.USER = "root";
      serviceConfig.KeepAlive = true;
      serviceConfig.RunAtLoad = true;
    };
  };
}
