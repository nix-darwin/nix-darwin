{ config, lib, pkgs, ... }:

with lib;

let
  redis = pkgs.runCommand "redis-0.0.0" {} "mkdir $out";
in

{
  system.primaryUser = "test-redis-user";

  services.redis.enable = true;
  services.redis.package = redis;
  services.redis.extraConfig = ''
    maxmemory-policy allkeys-lru
    stop-writes-on-bgsave-error no
  '';

  test = ''
    echo >&2 "checking redis service in ~/Library/LaunchAgents"
    grep "org.nixos.redis" ${config.out}/user/Library/LaunchAgents/org.nixos.redis.plist
    grep "${redis}/bin/redis-server /etc/redis.conf" ${config.out}/user/Library/LaunchAgents/org.nixos.redis.plist

    echo >&2 "checking config in /etc/redis.conf"
    grep "maxmemory-policy allkeys-lru" ${config.out}/etc/redis.conf
    grep "stop-writes-on-bgsave-error no" ${config.out}/etc/redis.conf
  '';
}
