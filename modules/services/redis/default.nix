{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.redis;
in

{
  options = {
    services.redis.enable = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to enable the redis database service.";
    };

    services.redis.package = mkOption {
      type = types.path;
      default = pkgs.redis;
      defaultText = "pkgs.redis";
      description = "This option specifies the redis package to use";
    };

    services.redis.dataDir = mkOption {
      type = types.nullOr types.path;
      default = "/var/lib/redis";
      description = "Data directory for the redis database.";
    };

    services.redis.port = mkOption {
      type = types.int;
      default = 6379;
      description = "The port for Redis to listen to.";
    };

    services.redis.bind = mkOption {
      type = types.nullOr types.str;
      default = null; # All interfaces
      description = "The IP interface to bind to.";
      example = "127.0.0.1";
    };

    services.redis.unixSocket = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "The path to the socket to bind to.";
      example = "/var/run/redis.sock";
    };

    services.redis.appendOnly = mkOption {
      type = types.bool;
      default = false;
      description = "By default data is only periodically persisted to disk, enable this option to use an append-only file for improved persistence.";
    };

    services.redis.extraConfig = mkOption {
      type = types.lines;
      default = "";
      description = "Additional text to be appended to {file}`redis.conf`.";
    };
  };

  config = mkIf cfg.enable {

    environment.systemPackages = [ cfg.package ];

    launchd.user.agents.redis = {
      command = "${cfg.package}/bin/redis-server /etc/redis.conf";
      serviceConfig.KeepAlive = true;
      managedBy = "services.redis.enable";
    };

    environment.etc."redis.conf".text = ''
      port ${toString cfg.port}
      ${optionalString (cfg.bind != null) "bind ${cfg.bind}"}
      ${optionalString (cfg.unixSocket != null) "unixsocket ${cfg.unixSocket}"}
      ${optionalString (cfg.dataDir != null) "dir ${cfg.dataDir}"}
      appendOnly ${if cfg.appendOnly then "yes" else "no"}
      ${cfg.extraConfig}
    '';

  };
}
