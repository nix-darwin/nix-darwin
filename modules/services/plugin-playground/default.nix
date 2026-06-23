{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.plugin-playground;

  boolToStr = b: if b then "true" else "false";
in {
  options.services.plugin-playground = {
    enable = mkEnableOption "Plugin Playground runtime tweak system";

    package = mkOption {
      type = types.package;
      default = pkgs.plugin-playground;
      defaultText = literalExpression "pkgs.plugin-playground";
      description = "The Plugin Playground package to use.";
    };

    disablePAC = mkOption {
      type = types.bool;
      default = true;
      description = "Disables arm64e PAC signing for spawned processes. Required if compiling without native arm64e ABI.";
    };

    useLegacyAmmonia = mkOption {
      type = types.bool;
      default = false;
      description = "Uses the legacy tweak path (/private/var/ammonia/core/tweaks/) instead of the default.";
    };

    pauseInjection = mkOption {
      type = types.bool;
      default = false;
      description = "Globally pauses tweak injection for all processes.";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];

    system.activationScripts.pluginPlayground.text = ''
      echo "Configuring Plugin Playground..."
      mkdir -p /opt/pluginplayground/tweaks
      mkdir -p /var/log/pluginplayground
      chmod 777 /opt/pluginplayground/tweaks
      chmod 777 /var/log/pluginplayground

      if [ ! -f /opt/pluginplayground/current.options ]; then
        touch /opt/pluginplayground/current.options
        chmod 666 /opt/pluginplayground/current.options
      fi

      defaults write /opt/pluginplayground/current.options disablePAC -bool ${boolToStr cfg.disablePAC}
      defaults write /opt/pluginplayground/current.options useLegacyAmmonia -bool ${boolToStr cfg.useLegacyAmmonia}
      defaults write /opt/pluginplayground/current.options pauseInjection -bool ${boolToStr cfg.pauseInjection}
      chmod 666 /opt/pluginplayground/current.options
    '';

    launchd.daemons.plugin-playground-grant = {
      serviceConfig = {
        Label = "com.pluginplayground.grant";
        ProgramArguments = [ "${cfg.package}/bin/grant" ];
        RunAtLoad = true;
        KeepAlive = true;
        StandardOutPath = "/var/log/pluginplayground/grant.log";
        StandardErrorPath = "/var/log/pluginplayground/grant.err";
      };
    };
  };

  meta.maintainers = [ lib.maintainers.aspauldingcode or "aspauldingcode" ];
}
