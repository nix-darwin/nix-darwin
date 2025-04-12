{ config, lib, pkgs, ... }:

with lib;

let

  cfg = config.services.ipfs;

in
{
  meta.maintainers = [ "jmmaloney4" ];

  options.services.ipfs = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Whether to enable the ipfs daemon.";
      };

      package = mkOption {
        type = types.package;
        default = pkgs.kubo;
        # defaultText = "pkgs.kubo";
        description = ''
          The ipfs package to use.
        '';
      };

      logFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        example =  "/var/tmp/ipfs.log";
        description = ''
          The logfile to use for the ipfs service. Alternatively
          {command}`sudo launchctl debug system/org.nixos.ipfs --stderr`
          can be used to stream the logs to a shell after restarting the service with
          {command}`sudo launchctl kickstart -k system/org.nixos.ipfs`.
        '';
      };

      ipfsPath = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Set the IPFS_PATH environment variable.";
      };

      enableGarbageCollection = mkOption {
        type = types.bool;
        default = false;
        description = "Passes --enable-gc flag to ipfs daemon.";
      };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];
    launchd.user.agents.ipfs = {
      serviceConfig = {
        ProgramArguments = [ "${cfg.package}/bin/ipfs" "daemon" ]
          ++ optionals (cfg.enableGarbageCollection) [ "--enable-gc" ];
        KeepAlive = true;
        RunAtLoad = true;
        ProcessType = "Background";
        StandardOutPath = cfg.logFile;
        StandardErrorPath = cfg.logFile;
        EnvironmentVariables = {} // (optionalAttrs (cfg.ipfsPath != null) { IPFS_PATH = cfg.ipfsPath; });
      };
      managedBy = "services.ipfs.enable";
    };
  };
}
