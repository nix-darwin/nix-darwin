{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.mopidy;
in

{
  options = {
    services.mopidy.enable = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to enable the Mopidy Daemon.";
    };

    services.mopidy.package = mkOption {
      type = types.path;
      default = pkgs.mopidy;
      defaultText = "pkgs.mopidy";
      description = "This option specifies the mopidy package to use.";
    };

    services.mopidy.mediakeys.enable = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to enable the Mopidy OSX Media Keys support daemon.";
    };

    services.mopidy.mediakeys.package = mkOption {
      type = types.path;
      default = pkgs.pythonPackages.osxmpdkeys;
      defaultText = "pkgs.pythonPackages.osxmpdkeys";
      description = "This option specifies the mediakeys package to use.";
    };
  };

  config = mkMerge [
    (mkIf cfg.enable {
      launchd.user.agents.mopidy = {
        serviceConfig.Program = "${cfg.package}/bin/mopidy";
        serviceConfig.RunAtLoad = true;
        serviceConfig.KeepAlive = true;
        managedBy = "services.mopidy.enable";
      };
    })
    (mkIf cfg.mediakeys.enable {
      launchd.user.agents.mopidymediakeys = {
        serviceConfig.Program = "${cfg.package}/bin/mpdkeys";
        serviceConfig.RunAtLoad = true;
        serviceConfig.KeepAlive = true;
        managedBy = "services.mopidy.mediakeys.enable";
      };
    })
  ];
}
