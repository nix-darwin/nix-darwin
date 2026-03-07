# Based off:
# https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/services/misc/nix-optimise.nix
# When making changes please try to keep it in sync.
{ config, lib, ... }:

let
  inherit (lib)
    mkIf
    mkOption
    mkRemovedOptionModule
    optionalString
    types
    ;

  cfg = config.nix.optimise;
  launchdTypes = import ../../launchd/types.nix { inherit config lib; };
in

{
  imports = [
    (mkRemovedOptionModule [ "nix" "optimise" "dates" ] "Use `nix.optimise.interval` instead.")
    (mkRemovedOptionModule [
      "nix"
      "optimise"
      "user"
    ] "The store optimisation service now always runs as `root`.")
  ];

  ###### interface

  options = {

    nix.optimise = {

      automatic = mkOption {
        type = types.bool;
        default = false;
        description = "Automatically run the nix store optimiser at a specific time.";
      };

      interval = mkOption {
        type = launchdTypes.StartCalendarInterval;
        default = [
          {
            Weekday = 7;
            Hour = 4;
            Minute = 15;
          }
        ];
        description = ''
          The calendar interval at which the optimiser will run.
          See the {option}`serviceConfig.StartCalendarInterval` option of
          the {option}`launchd` module for more info.
        '';
      };

    };

  };

  ###### implementation

  config = {
    assertions = [
      {
        assertion = cfg.automatic -> config.nix.enable;
        message = "nix.optimise.automatic requires nix.enable";
      }
    ];

    launchd.daemons.nix-optimise = mkIf cfg.automatic {
      command = "${lib.getExe' config.nix.package "nix-store"} --optimise";
      serviceConfig = {
        RunAtLoad = false;
        StartCalendarInterval = cfg.interval;
      };
    };
  };
}
