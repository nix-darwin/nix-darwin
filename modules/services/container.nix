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

      enableKernelInstall = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Whether the default kernel should be installed or not.
        '';
      };

      appRoot = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          Path to the root directory for application data.
        '';
      };

      installRoot = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          Path to the root directory for application executables and plugins
        '';
      };
    };
  };

  config = lib.mkIf (cfg.enable != null) {
    environment.systemPackages = lib.optionals (cfg.enable) [
      cfg.package
    ];

    system.activationScripts.launchd.text =
    let
      kernelInstall = if cfg.enableKernelInstall then "--enable-kernel-install" else "--disable-kernel-install";
      installRootArg = lib.optionalString (cfg.installRoot != null) ''--install-root "${cfg.installRoot}"'';
      appRootArg = lib.optionalString (cfg.appRoot != null) ''--app-root "${cfg.appRoot}"'';
    in if cfg.enable then ''
      # If /run/current-system/sw/bin/container does not match package path, assume upgrade/downgrade
      _prev=$(readlink -f /run/current-system/sw/bin/container 2>/dev/null || true)
      _new="${cfg.package}/bin/container"
      if [ -n "$_prev" ] && [ "$_prev" != "$_new" ]
      then
        echo "Apple Container update detected. Stopping container service."
        # Sometimes container can hang, violently stop it (see https://github.com/apple/container/issues/1329#issuecomment-4095140386)
        /usr/bin/sudo -u ${config.system.primaryUser} launchctl bootout gui/"$(id -u ${config.system.primaryUser})"/com.apple.container.apiserver &>/dev/null || true
        /usr/bin/sudo -u ${config.system.primaryUser} launchctl remove com.apple.container.apiserver &>/dev/null || true
        pkill -9 -f com.apple.container &>/dev/null || true
        /usr/bin/sudo -u ${config.system.primaryUser} ${cfg.package}/bin/container system stop
        # -k preserves user data
        /run/current-system/sw/bin/uninstall-container.sh -k
      fi

      echo "Starting Apple container service."
      /usr/bin/sudo -u ${config.system.primaryUser} ${cfg.package}/bin/container system start ${installRootArg} ${appRootArg} ${kernelInstall}
    '' else ''
      /usr/bin/sudo -u ${config.system.primaryUser} ${cfg.package}/bin/container system stop
    '';
  };
}
