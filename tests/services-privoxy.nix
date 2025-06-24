{ config, lib, pkgs, ... }:

with lib;

let
  privoxy = pkgs.runCommand "privoxy-0.0.0" {} "mkdir $out";
in

{
  system.primaryUser = "test-privoxy-user";

  services.privoxy.enable = true;
  services.privoxy.package = privoxy;
  services.privoxy.config = "forward / .";

  test = ''
    echo >&2 "checking privoxy service in ~/Library/LaunchAgents"
    grep "org.nixos.privoxy" ${config.out}/user/Library/LaunchAgents/org.nixos.privoxy.plist
    echo grep "${privoxy}/bin/privoxy" ${config.out}/user/Library/LaunchAgents/org.nixos.privoxy.plist
    grep "${privoxy}/bin/privoxy" ${config.out}/user/Library/LaunchAgents/org.nixos.privoxy.plist

    echo >&2 "checking config in /etc/privoxy-config"
    grep "forward / ." ${config.out}/etc/privoxy-config
  '';
}
