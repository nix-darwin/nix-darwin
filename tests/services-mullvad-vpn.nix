{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
let
  mullvad-vpn = pkgs.runCommand "mullvad-vpn-0.0.0" { } "mkdir $out";
in
{
  services.mullvad-vpn = {
    enable = true;
    package = mullvad-vpn;
  };

  test = ''
    echo >&2 "checking mullvad-vpn service in launchd daemons"
    grep "mullvad" ${config.out}/Library/LaunchDaemons/net.mullvad.daemon.plist
    grep "${mullvad-vpn}/bin/mullvad-daemon" ${config.out}/Library/LaunchDaemons/net.mullvad.daemon.plist
  '';
}
