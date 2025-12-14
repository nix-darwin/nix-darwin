{ config, lib, pkgs, ... }:

let
  inherit (lib) mkEnableOption mkOption types mkIf;

  cfg = config.services.telegraf;

  settingsFormat = pkgs.formats.toml { };
  configFile = settingsFormat.generate "config.toml" cfg.extraConfig;
in {
  options = {
    services.telegraf = {
      enable = mkEnableOption "telegraf agent";

      package = mkOption {
        default = pkgs.telegraf;
        defaultText = lib.literalExpression "pkgs.telegraf";
        description = "Which telegraf derivation to use";
        type = types.package;
      };

      environmentFiles = mkOption {
        type = types.listOf types.path;
        default = [ ];
        example = [ "/run/keys/telegraf.env" ];
        description = ''
          File to load as environment file.
          This is useful to avoid putting secrets into the nix store.
        '';
      };

      extraConfig = mkOption {
        default = { };
        description = "Extra configuration options for telegraf";
        type = settingsFormat.type;
        example = {
          outputs.influxdb = {
            urls = [ "http://localhost:8086" ];
            database = "telegraf";
          };
          inputs.statsd = {
            service_address = ":8125";
            delete_timings = true;
          };
        };
      };

      configUrl = mkOption {
        default = null;
        description = "Url to fetch config from";
        type = types.nullOr types.str;
      };
    };
  };

  config = mkIf cfg.enable {
    launchd.daemons.telegraf = {
      script = ''
        ${lib.concatStringsSep "\n"
        (map (file: "source ${file}") cfg.environmentFiles)}
        ${cfg.package}/bin/telegraf --config ${
          if cfg.configUrl == null then configFile else cfg.configUrl
        }
      '';
      serviceConfig = {
        KeepAlive = true;
        RunAtLoad = true;
      };

      # https://github.com/influxdata/telegraf/issues/17607
      environment.HOME = "/var/root";
    };
  };
}
