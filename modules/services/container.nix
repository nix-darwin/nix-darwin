{ config, pkgs, lib, ... }:

let
  cfg = config.services.container;
in
{
  meta.maintainers = [
    lib.maintainers.heywoodlh or "heywoodlh"
  ];

  options = {
    services.container = {
      enable = lib.mkOption {
        type = lib.types.nullOr lib.types.bool;
        default = null;
        description = ''
          Whether to enable Apple's container service.
        '';
      };

      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.container;
        description = ''
          Package containing `container` executable.
        '';
      };

      user = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          User running the container service.
        '';
      };

      enableKernelInstall = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Whether the default kernel should be installed or not.
        '';
      };

      # TODO add `appRoot` and `installRoot` parameters when default documented: https://github.com/apple/container/issues/622
    };
  };

  config = lib.mkIf (cfg.enable != null) {
    assertions = [
      {
        assertion = (cfg.user != null);
        message = "`services.container.user`: Required parameter services.container.user is unset.;";
      }
    ];
    environment.systemPackages = lib.optionals (cfg.enable) [
      cfg.package
    ];

    system.activationScripts.launchd.text =
    let
      kernelInstall = if cfg.enableKernelInstall then "--enable-kernel-install" else "--disable-kernel-install";
    in if cfg.enable then ''
      set -ex
      /usr/bin/sudo -u ${cfg.user} ${cfg.package}/bin/container system start ${kernelInstall}
    '' else ''
      set -ex
      /usr/bin/sudo -u ${cfg.user} ${cfg.package}/bin/container system stop
    '';
  };
}
