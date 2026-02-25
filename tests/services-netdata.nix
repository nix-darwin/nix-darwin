{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  netdata = pkgs.runCommand "netdata-0.0.0" { } "mkdir $out";
in
{
  services.netdata = {
    enable = true;
    package = netdata;
  };

  test = ''
    echo >&2 "checking netdata service in launchd daemons"
    grep "netdata" ${config.out}/Library/LaunchDaemons/netdata.plist
    grep "${netdata}/bin/netdata" ${config.out}/Library/LaunchDaemons/netdata.plist
  '';
}
