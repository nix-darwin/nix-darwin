{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.services.trezord;
in {
  # Options copied from:
  # https://github.com/NixOS/nixpkgs/blob/9d6e454b857fb472fa35fc8b098fa5ac307a0d7d/nixos/modules/services/hardware/trezord.nix#L16
  options = {
    services.trezord = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Enable Trezor bridge daemon, for use with Trezor hardware wallets.
        '';
      };

      emulator.enable = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Enable Trezor emulator support.
        '';
       };

      emulator.port = mkOption {
        type = types.port;
        default = 21324;
        description = ''
          Listening port for the Trezor emulator.
        '';
      };
    };
  };

  config = mkIf cfg.enable {
    launchd.user.agents.trezord = {
      command = "${lib.getExe' pkgs.trezord "trezord-go"} ${lib.optionalString cfg.emulator.enable "-e ${builtins.toString cfg.emulator.port}"}";
      serviceConfig = {
        KeepAlive = true;
        RunAtLoad = true;
      };
      managedBy = "services.trezord.enable";
    };
  };
}
