{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.freenet-core;

  command = [
    (lib.getExe cfg.package)
    "network"
    "--disable-auto-update"
    "--network-address=${cfg.networkAddress}"
    "--network-port=${toString cfg.networkPort}"
    "--ws-api-address=${cfg.websocketAddress}"
    "--ws-api-port=${toString cfg.websocketPort}"
  ]
  ++ lib.optional (cfg.configDir != null) "--config-dir=${cfg.configDir}"
  ++ lib.optional (cfg.dataDir != null) "--data-dir=${cfg.dataDir}"
  ++ lib.optional (cfg.logDir != null) "--log-dir=${cfg.logDir}"
  ++ cfg.extraArgs;
in
{
  options.services.freenet-core = {
    enable = lib.mkEnableOption "Freenet node";

    package = lib.mkPackageOption pkgs "freenet-core" { };

    dataDir = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      example = "/Users/alice/Library/Application Support/Freenet";
      description = ''
        Directory used to store Freenet node data. When unset, Freenet uses its
        platform-specific default for the primary user.
      '';
    };

    configDir = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      example = "/Users/alice/Library/Application Support/Freenet/config";
      description = ''
        Directory used to store Freenet configuration. When unset, Freenet uses
        its platform-specific default for the primary user.
      '';
    };

    logDir = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      example = "/Users/alice/Library/Logs/Freenet";
      description = ''
        Directory used to store Freenet logs. When unset, Freenet uses its
        platform-specific default for the primary user.
      '';
    };

    networkAddress = lib.mkOption {
      type = lib.types.str;
      default = "::";
      example = "0.0.0.0";
      description = "Address on which the Freenet peer-to-peer transport listens.";
    };

    networkPort = lib.mkOption {
      type = lib.types.port;
      default = 31337;
      example = 31338;
      description = "UDP port on which the Freenet peer-to-peer transport listens.";
    };

    websocketAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      example = "::1";
      description = "Address on which the Freenet HTTP and WebSocket API listens.";
    };

    websocketPort = lib.mkOption {
      type = lib.types.port;
      default = 7509;
      example = 7510;
      description = "TCP port on which the Freenet HTTP and WebSocket API listens.";
    };

    nice = lib.mkOption {
      type = lib.types.ints.between (-20) 19;
      default = 10;
      example = 5;
      description = "Nice level for the Freenet process.";
    };

    environment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      example = {
        RUST_LOG = "freenet=debug";
      };
      description = "Environment variables passed to the Freenet process.";
    };

    extraArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [
        "--telemetry-enabled"
        "--total-bandwidth-limit=10000000"
      ];
      description = "Additional command-line arguments passed to Freenet.";
    };
  };

  config = lib.mkIf cfg.enable {
    launchd.user.agents.freenet-core = {
      serviceConfig = {
        ProgramArguments = command;
        EnvironmentVariables = cfg.environment;
        KeepAlive.SuccessfulExit = false;
        RunAtLoad = true;
        ProcessType = "Background";
        Nice = cfg.nice;
        ThrottleInterval = 10;
        ExitTimeOut = 45;
      };
      managedBy = "services.freenet-core.enable";
    };
  };

  meta.maintainers = [ lib.maintainers.LisaScheers or "LisaScheers" ];
}
