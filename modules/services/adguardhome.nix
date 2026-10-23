{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.services.adguardhome;
  settingsFormat = pkgs.formats.yaml { };

  settings =
    if (cfg.settings != null) then
      cfg.settings
      // (
        if cfg.settings.schema_version < 23 then
          {
            bind_host = cfg.host;
            bind_port = cfg.port;
          }
        else
          {
            http.address = "${cfg.host}:${toString cfg.port}";
          }
      )
    else
      { };

  configFile = (settingsFormat.generate "AdGuardHome.yaml" settings).overrideAttrs (_: {
    checkPhase = "${cfg.package}/bin/adguardhome -c $out --check-config";
  });
in
{
  options.services.adguardhome = with lib.types; {
    enable = lib.mkEnableOption "AdGuard Home network-wide ad blocker";

    package = lib.mkOption {
      type = package;
      default = pkgs.adguardhome;
      defaultText = lib.literalExpression "pkgs.adguardhome";
      description = ''
        The package that runs adguardhome.
      '';
    };

    host = lib.mkOption {
      default = "0.0.0.0";
      type = str;
      description = ''
        Host address to bind HTTP server to.
      '';
    };

    port = lib.mkOption {
      default = 3000;
      type = port;
      description = ''
        Port to serve HTTP pages on.
      '';
    };

    settings = lib.mkOption {
      default = null;
      type = nullOr (submodule {
        freeformType = settingsFormat.type;
        options = {
          schema_version = lib.mkOption {
            default = cfg.package.schema_version;
            defaultText = lib.literalExpression "cfg.package.schema_version";
            type = int;
            description = ''
              Schema version for the configuration.
              Defaults to the `schema_version` supplied by `cfg.package`.
            '';
          };
        };
      });
      description = ''
        AdGuard Home configuration. Refer to
        <https://github.com/AdguardTeam/AdGuardHome/wiki/Configuration#configuration-file>
        for details on supported values.

        ::: {.note}
        On start and if {option}`mutableSettings` is `true`,
        these options are merged into the configuration file on start, taking
        precedence over configuration changes made on the web interface.

        Set this to `null` (default) for a non-declarative configuration without any
        Nix-supplied values.
        Declarative configurations are supplied with a default `schema_version`, and `http.address`.
        :::
      '';
    };

    extraArgs = lib.mkOption {
      default = [ ];
      type = listOf str;
      description = ''
        Extra command line parameters to be passed to the adguardhome binary.
      '';
    };

    logFile = mkOption {
      type = types.nullOr types.path;
      default = "/var/log/adguardhome.log";
      description = ''
        The logfile to use for the AdGuard Home service. Alternatively
        {command}`sudo launchctl debug system/org.nixos.adguardhome --stderr`
        can be used to stream the logs to a shell after restarting the service with
        {command}`sudo launchctl kickstart -k system/org.nixos.adguardhome`.
      '';
    };
  };

  config = mkIf cfg.enable {
    launchd.daemons.adguardhome = {
      command = "${lib.getExe cfg.package} -c ${configFile} --no-check-update ${builtins.concatStringsSep " " cfg.extraArgs}";
      serviceConfig = {
        KeepAlive = true;
        RunAtLoad = true;
        StandardErrorPath = cfg.logFile;
        StandardOutPath = cfg.logFile;
      };
    };
  };
}
