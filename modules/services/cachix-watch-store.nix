{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.services.cachix-watch-store;
in
{
  meta.maintainers = [ lib.maintainers.skyethepinkcat or "skyethepinkcat" ];
  options.services.cachix-watch-store = {
    enable = lib.mkEnableOption "Cachix Watch Store: <https://docs.cachix.org>";

    cacheName = lib.mkOption {
      type = lib.types.str;
      description = "Cachix binary cache name";
    };

    cachixTokenFile = lib.mkOption {
      type = lib.types.path;
      description = ''
        Required file that needs to contain the cachix auth token.
      '';
    };

    signingKeyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      description = ''
        Optional file containing a self-managed signing key to sign uploaded store paths.
      '';
      default = null;
    };

    compressionLevel = lib.mkOption {
      type = lib.types.nullOr (lib.types.ints.between 0 16);
      description = "The compression level for ZSTD compression (between 0 and 16)";
      default = null;
    };

    jobs = lib.mkOption {
      type = lib.types.nullOr lib.types.ints.positive;
      description = "Number of threads used for pushing store paths";
      default = null;
    };

    host = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Cachix host to connect to";
    };

    verbose = lib.mkOption {
      type = lib.types.bool;
      description = "Enable verbose output";
      default = false;
    };

    logFile = mkOption {
      type = types.nullOr types.path;
      default = "/var/log/cachix-watch-store.log";
      description = "Absolute path to log all stderr and stdout";
    };

    package = lib.mkPackageOption pkgs "cachix" { };
  };

  config = mkIf cfg.enable {
    launchd.daemons.cachix-watch-store = {
      script =
        let
          command = [
            "${cfg.package}/bin/cachix"
          ]
          ++ (lib.optional cfg.verbose "--verbose")
          ++ (lib.optionals (cfg.host != null) [
            "--host"
            cfg.host
          ])
          ++ [ "watch-store" ]
          ++ (lib.optionals (cfg.compressionLevel != null) [
            "--compression-level"
            (toString cfg.compressionLevel)
          ])
          ++ (lib.optionals (cfg.jobs != null) [
            "--jobs"
            (toString cfg.jobs)
          ])
          ++ [ cfg.cacheName ];
        in
        ''

          export CACHIX_AUTH_TOKEN="$(<"${cfg.cachixTokenFile}")"
          ${lib.optionalString (
            cfg.signingKeyFile != null
          ) ''export CACHIX_SIGNING_KEY="$(<"${cfg.signingKeyFile}"''}
          ${lib.escapeShellArgs command}
        '';

      environment = {
        USER = "root";
      };

      serviceConfig = {
        KeepAlive = true;
        ProcessType = "Background";
        RunAtLoad = true;
        StandardErrorPath = cfg.logFile;
        StandardOutPath = cfg.logFile;
        WatchPaths = [
          cfg.cachixTokenFile
        ]
        ++ lib.optionals (cfg.signingKeyFile != null) [ cfg.signingKeyFile ];
      };
    };
  };
}
