{
  config,
  lib,
  pkgs,
  ...
}:

let

  cfg = config.services.dnscrypt-proxy;

  format = pkgs.formats.toml { };

  configFile = format.generate "dnscrypt-proxy.toml" cfg.settings;

in

{
  options.services.dnscrypt-proxy = {

    enable = lib.mkEnableOption "the dnscrypt-proxy service.";

    package = lib.mkPackageOption pkgs "dnscrypt-proxy" { };

    settings = lib.mkOption {
      description = ''
        Attrset that is converted and passed as TOML config file.
        For available params, see: <https://github.com/DNSCrypt/dnscrypt-proxy/blob/${pkgs.dnscrypt-proxy.version}/dnscrypt-proxy/example-dnscrypt-proxy.toml>
      '';
      example = lib.literalExpression ''
        {
          sources.public-resolvers = {
            urls = [ "https://download.dnscrypt.info/resolvers-list/v2/public-resolvers.md" ];
            cache_file = "public-resolvers.md";
            minisign_key = "RWQf6LRCGA9i53mlYecO4IzT51TGPpvWucNSCh1CBM0QTaLn73Y7GFO3";
            refresh_delay = 72;
          };
        }
      '';
      type = format.type;
      default = { };
    };
  };

  config = lib.mkIf cfg.enable {
    users.users._dnscrypt-proxy = {
      uid = config.ids.uids._dnscrypt-proxy;
      gid = config.ids.gids._dnscrypt-proxy;
      home = "/private/var/lib/dnscrypt-proxy";
      createHome = true;
      shell = "/usr/bin/false";
      description = "System user for dnscrypt-proxy";
    };

    users.groups._dnscrypt-proxy = {
      gid = config.ids.gids._dnscrypt-proxy;
      description = "System group for dnscrypt-proxy";
    };

    users.knownUsers = [ "_dnscrypt-proxy" ];
    users.knownGroups = [ "_dnscrypt-proxy" ];

    launchd.daemons.dnscrypt-proxy = {
      script = ''
        ${lib.getExe' cfg.package "dnscrypt-proxy"} -config ${configFile}
      '';
      serviceConfig =
        let
          logPath = config.users.users._dnscrypt-proxy.home + "/dnscrypt-proxy.log";
        in
        {
          RunAtLoad = true;
          KeepAlive = true;
          StandardOutPath = logPath;
          StandardErrorPath = logPath;
          GroupName = "_dnscrypt-proxy";
          UserName = "_dnscrypt-proxy";
        };
    };
  };
}
