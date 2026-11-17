{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.harmonia;
  cacheCfg = cfg.cache;

  format = pkgs.formats.toml { };
in

{
  meta.maintainers = [
    lib.maintainers.anish or "anish"
  ];

  options.services.harmonia = {
    package = lib.mkPackageOption pkgs "harmonia" { };

    cache = {
      enable = lib.mkEnableOption "Harmonia binary cache";

      signKeyPaths = lib.mkOption {
        type = lib.types.listOf lib.types.externalPath;
        default = [ ];
        description = ''
          Paths to the signing keys to use for signing the cache. Each must be
          readable by the `_harmonia` user.
        '';
      };

      settings = lib.mkOption {
        inherit (format) type;
        default = { };
        description = ''
          Settings to merge with the default configuration.
          For the list of the default configuration, see <https://github.com/nix-community/harmonia/tree/master#configuration>.
        '';
      };
    };
  };

  config = lib.mkIf cacheCfg.enable {
    services.harmonia.cache.settings =
      builtins.mapAttrs (_: v: lib.mkDefault v) {
        bind = "[::]:5000";
        workers = 4;
        max_connection_rate = 256;
        priority = 50;
      }
      // {
        sign_key_paths = cacheCfg.signKeyPaths;
      };

    users.users._harmonia = {
      uid = config.ids.uids._harmonia;
      gid = config.ids.gids._harmonia;
      home = "/var/lib/harmonia";
      createHome = true;
      shell = "/usr/bin/false";
      description = "System user for Harmonia";
    };

    users.groups._harmonia = {
      gid = config.ids.gids._harmonia;
      description = "System group for Harmonia";
    };

    users.knownUsers = [ "_harmonia" ];
    users.knownGroups = [ "_harmonia" ];

    launchd.daemons.harmonia = {
      command = lib.getExe cfg.package;
      environment.CONFIG_FILE = toString (format.generate "harmonia.toml" cacheCfg.settings);
      serviceConfig =
        let
          logPath = config.users.users._harmonia.home + "/harmonia.log";
        in
        {
          KeepAlive = true;
          RunAtLoad = true;
          StandardOutPath = logPath;
          StandardErrorPath = logPath;
          GroupName = "_harmonia";
          UserName = "_harmonia";
        };
    };
  };
}
